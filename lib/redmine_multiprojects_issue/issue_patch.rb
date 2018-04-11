require_dependency 'issue'

module RedmineMultiprojectsIssue
  module PrependedIssuePatch
    # Returns the users that should be notified
    def notified_users
      super | notified_users_from_other_projects
    end
  end
end
Issue.prepend RedmineMultiprojectsIssue::PrependedIssuePatch

class Issue < ActiveRecord::Base

  include ApplicationHelper

  unloadable # Send unloadable so it will not be unloaded in development

  has_and_belongs_to_many :projects
  attr_accessor :assignable_projects #List related projects before save
  after_save :set_projects

  safe_attributes 'answers_on_secondary_projects'
  #adds a new "safe_attributes condition to handle the case of secondary projects
  safe_attributes 'notes', :if => lambda {|issue, user| issue.editable?(user)}

  unless instance_methods.include?(:visible_with_multiproject_issues?)
    # Returns true if usr or current user is allowed to view the issue
    def visible_with_multiproject_issues?(usr=nil)
      visible_without_multiproject_issues?(usr) || other_project_visible?(usr)
    end
    alias_method_chain :visible?, :multiproject_issues
  end

  # Overrides Redmine::Acts::Attachable::InstanceMethods#attachments_visible?
  def attachments_visible?(user=User.current)
    # Check if user is allowed to see attached files in at least one of the impacted projects
    allowed = false
    (self.projects + [self.project]).each do |project|
      allowed = allowed || user.allowed_to?(self.class.attachable_options[:view_permission], project)
      break if allowed
    end
    (respond_to?(:visible?) ? visible?(user) : true) && allowed
  end

  def other_project_visible?(usr=nil)
    other_projects = self.projects - [self.project]
    visible_projects = other_projects.detect do |p|
      (usr || User.current).allowed_to?(:view_issues, p) do |role, user|
        visible = if user.logged?
          case role.issues_visibility
          when 'all'
            true
          when 'default'
            !self.is_private? || (self.author == user || user.is_or_belongs_to?(assigned_to))
          when 'own'
            self.author == user || user.is_or_belongs_to?(assigned_to)
          else
            false
          end
        else
          !self.is_private?
        end
        unless role.permissions_all_trackers?(:view_issues)
          visible &&= role.permissions_tracker_ids?(:view_issues, tracker_id)
        end
        visible
      end
    end
    visible_projects.present?
  end

  unless methods.include?(:visible_condition_with_multiproject_issues)
    def self.visible_condition_with_multiproject_issues(user, options={})
      statement_by_role = {}
      user.projects_by_role.each do |role, projects|
        projects = projects & [options[:project]] if options[:project]
        if role.allowed_to?(:view_issues) && projects.any?
          statement_by_role[role] = "project_id IN (#{projects.collect(&:id).join(',')})"
        end
      end
      authorized_projects = statement_by_role.values.join(' OR ')

      if authorized_projects.present?
        "(#{visible_condition_without_multiproject_issues(user, options)} OR #{Issue.table_name}.id IN (SELECT issue_id FROM issues_projects WHERE (#{authorized_projects}) ))"
      else
        visible_condition_without_multiproject_issues(user, options)
      end
    end
    self.singleton_class.send(:alias_method_chain, :visible_condition, :multiproject_issues)
  end

  def notified_users_from_other_projects
    notified = []
    other_projects = []
    other_projects |= self.assignable_projects unless self.assignable_projects == nil
    other_projects |= self.projects
    other_projects -= [self.project]
    other_projects.each do |p|

      notified_by_role = []
      p.users_by_role.each do |role, members|
        if role.allowed_to?(:view_issues)
          case role.issues_visibility
            when 'all'
              notified_by_role = notified_by_role | members
            when 'default'
              notified_by_role = notified_by_role | members if !self.is_private?
            when 'own'
              nil
            else
              nil
          end
        end
      end

      # users are notified only if :
      # - they are member and they have appropriate role
      # or
      # - they are member and they are admin
      if p.module_enabled?("limited_visibility") && self.authorized_viewer_ids.present?
        members = p.notified_users & self.involved_users(p)
      else
        members = p.notified_users
      end

      notified = notified | (notified_by_role & members) | (User.where("admin = ?", true).all & p.notified_users)

    end
    notified.compact
  end

  def user_tracker_permission_with_multiprojects?(user, permission)
    if user_tracker_permission_without_multiprojects?(user, permission) == true
      true
    else
      # Check roles permissions on other projects
      (answers_on_secondary_projects && projects.any?{|p|
        user.roles_for_project(p).select {|r| r.has_permission?(permission)}.any? {|r| r.permissions_all_trackers?(permission) || r.permissions_tracker_ids?(permission, tracker_id)}
      })
    end
  end
  alias_method_chain :user_tracker_permission?, :multiprojects

  def related_projects
    RelatedProjects.new(self, projects)
  end

  # Class used to represent the related projects of an issue
  class RelatedProjects < Array
    include Redmine::I18n

    def initialize(issue, *args)
      @issue = issue
      super(*args)
    end

    def to_s(*args)
      map {|v| v.to_s}.join(', ')
    end
  end

  private

    def set_projects
      self.projects = self.assignable_projects unless self.assignable_projects == nil
    end

end
