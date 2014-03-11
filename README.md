Redmine Multiprojects Issue plugin
======================

This redmine plugin allow you to specify more than one project per issue.

Cross-projects issues appear in all concerned projects,
can be viewed by every users who have enough permission on at least one project,
can be updated only by users who have enough permissions on the main project (the project used to create the issue).

Screenshots
------------

![redmine_multiprojects_issue screenshot](http://blog.nanego.com/images/multiproject_query.png)
![redmine_multiprojects_issue screenshot](http://blog.nanego.com/images/multiproject_show.png)
![redmine_multiprojects_issue screenshot](http://blog.nanego.com/images/multiproject_modify.png)

Installation
------------

This plugin has been tested with Redmine 2.3.0+.

Please apply general instructions for plugins [here](http://www.redmine.org/wiki/redmine/Plugins).

First download the source or clone the plugin and put it in the "plugins/" directory of your redmine instance. Note that this is crucial that the directory is named 'redmine_introductions'!

Then execute:

    $ bundle install
    $ rake redmine:plugins

And finally restart your Redmine instance.


Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request