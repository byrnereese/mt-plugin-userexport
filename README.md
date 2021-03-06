# Overview

The Export User Data plugin for Movable Type allows administrators to export all of the information collected about their site's users into a comma-separated format (.csv) file.

# Prerequisities

* Movable Type 4.x.

# Installation

To install this plugin follow the instructions found here:

http://tinyurl.com/easy-plugin-install

# Usage

System administrators will find an "Export user data" Page Action on the system-level Users screen. Click this to get started!

On the **Filter** screen you can home-in on the users you want, then click the Select Fields button to continue:

* Select the user's status. "Enabled" and "disabled" are clear options. "Pending" users are those who have registered with Movable Type, but who have not confirmed their registration.
* Select the user's role. This list allows multiple selections, and is most useful for specifically accessing your users, who likely have either the Commenter or Contributor role. Alternatively, by selecting Author, Editor, and Moderator you can generate a list of your site's administrative team, for example.
* Select the blog(s) to export from. If your Movable Type install runs multiple domains, being able to export user data for specific blogs is important.
* By default, only users who have used MT authentication will be exported, because those are the users with the most useful data. (Custom fields, for example, can only be filled-in by MT-authenticated users.) If you want to export the data from users who have authenticated through other methods such as TypePad or Facebook, in addition to those authenticated through MT, check this checkbox.

On the **Fields** screen you will find a table of author profile fields, including any custom fields that may be defined. Place checkmarks next to the fields that you want to include in your export data. Click and drag fields to re-arrange their order. Note that the User ID field will always be exported, and can not be reordered. Click the Export button to continue; depending upon the size of the dataset, this may take a few moments.

Lastly, on the **Export** screen you're presented with the result! The file name,  location, and size are reported here, as is a link to download the data. If you've enabled the Display Export Results option, you also see your exported data here.

The resulting comma-separated file can be imported and analyzed with Numbers or Excel or other spreadsheet application!

# Acknowledgements

This plugin was commissioned by Endevver to Dan Wolfgang of uiNNOVATIONS. Endevver is proud to be partners with uiNNOVATIONS.

http://uinnovations.com/

# License

This plugin is licensed under the same terms as Perl itself.

# Copyright

Copyright 2009, Endevver LLC. All rights reserved.