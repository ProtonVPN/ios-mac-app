# -*- coding: utf-8 -*-
import os.path
import os

#
# See http://dmgbuild.readthedocs.io/en/latest/index.html for docs
#

if not "app" in defines:
    raise Exception("App path needs to be defined on the command line. Use -Dapp=<path>.")

repo = defines.get("repo", os.getcwd())

application = defines["app"]
appname = os.path.basename(application)

# Volume format (see hdiutil create -help)
format = defines.get('format', 'UDBZ')

# Volume size
size = defines.get('size', None)

# Files to include
files = [ application ]

# Symlinks to create
symlinks = { 'Applications': '/Applications' }

# Note: paths are relative to the script's directory.
icon = repo + '/Integration/Assets/ProtonVPN-Disk-Image.icns' # Set the 'disk' icon to display when the dmg has been mounted
background = repo + '/Integration/Assets/Disk-Image-Background.pdf' # Set the dmg background to display when the image is opened

# Where to put the icons
icon_locations = {
    appname:        (130, 194),
    'Applications': (412, 194),
    '.background.pdf': (100, 468), # move the background file icon off screen
    '.VolumeIcon.icns': (100, 468) # move the disk icon file off screen
}

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 180

# Window position in ((x, y), (w, h)) format
window_rect = ((200, 200), (548, 412))

default_view = 'icon-view'

# General view configuration
show_icon_preview = False

# Set these to True to force inclusion of icon/list view settings (otherwise
# we only include settings for the default view)
include_icon_view_settings = 'auto'
include_list_view_settings = 'auto'

# .. Icon view configuration ...................................................

arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = 'bottom' # or 'right'
text_size = 14
icon_size = 96

# .. List view configuration ...................................................

# Column names are as follows:
#
#   name
#   date-modified
#   date-created
#   date-added
#   date-last-opened
#   size
#   kind
#   label
#   version
#   comments
#
list_icon_size = 16
list_text_size = 12
list_scroll_position = (0, 0)
list_sort_by = 'name'
list_use_relative_dates = True
list_calculate_all_sizes = False,
list_columns = ('name', 'date-modified', 'size', 'kind', 'date-added')

list_column_widths = {
    'name': 300,
    'date-modified': 181,
    'date-created': 181,
    'date-added': 181,
    'date-last-opened': 181,
    'size': 97,
    'kind': 115,
    'label': 100,
    'version': 75,
    'comments': 300,
}

list_column_sort_directions = {
    'name': 'ascending',
    'date-modified': 'descending',
    'date-created': 'descending',
    'date-added': 'descending',
    'date-last-opened': 'descending',
    'size': 'descending',
    'kind': 'ascending',
    'label': 'ascending',
    'version': 'ascending',
    'comments': 'ascending',
}
