
See [A New Look Leads to a New Blogging System](http://www.windley.com/archives/2013/04/a_new_look_leads_to_a_new_blogging_system.shtml) for information about this blogging system. 

This system depends on files in a specific directory hierarchy and with specific meta data in the HTML comments. The [elisp file I use for blogging](https://github.com/windley/emacs/blob/master/blogging.el) is specifically designed to create files with the correct format in the right directory hierarchy. 

I've recently added ability to sync with AWS using the AWS CLI tool. Here's some information about installing CLI:

- [PIP is a pre-requisite](http://stackoverflow.com/questions/17271319/how-to-install-pip-on-mac-os-x)
- [Installing AWS CLI](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)
	- `sudo pip install awscli --ignore-installed six`
- [Syncing with AWS sync](http://docs.aws.amazon.com/cli/latest/userguide/using-s3-commands.html)
