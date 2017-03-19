#!/usr/bin/python
#
"""
MODULE:    r_tg_geom.py

AUTHOR(S): Edina Jozsa <edina.j0zs4 AT gmail.com>
           Adriana Sarasan

PURPOSE:   This script is created to calculate topographic grain as
           significant distance of major ridges and valleys to help
           setting proper search parameters for geomorphometric mapping
           especially for r.geomorphon tool which is included with
           suggested settings.

NOTES:     The tool defines the locally significant ridgeline-to-channel
           spacing by calculating relative relief values with nested
           neighborhood matrices. Relative relief values are plotted
           against corresponding neighborhood matrice areas and breaks
           of curve are detected where the convex change of curve is
           sharpest.

DEPENDENCIES:    R 3.x (packages: spgrass6/rgrass7, ggplot2, plyr) &
            r.geomorphon add-on

COPYRIGHT: (C) 2015-2017 Edina Jozsa & Adriana Sarasan
           and the GRASS Development Team

           This program is free software under the GNU General Public
           License (>=v2). Read the file COPYING that comes with GRASS
           for details.


REFERENCES:
Mark, D.M., 1975. Geomorphometric parameters: a review and evaluation.
Geografiska Annaler. Series A, Physical Geography, Vol. 57,
No. 3/4 (1975), pp. 165-177.
Pike, R.J., Acevedo,W., Card, D.H., 1989. Topographic grain automated
from digital elevation models.
In: Proceedings of the Ninth International Symposium on Computer
Assisted Cartogtraphy. ASPRS/ASCM, Baltimore, MD, pp. 128-137.

"""

#%Module
#% description: Estimates topographic grain
#% keyword: raster
#% keyword: terrain
#% keyword: geomorphology
#% keyword: elevation
#% keyword: landform
#%End

#%option G_OPT_R_ELEV
#% key: elevation
#% description: Name of input elevation model
#% guisection: Topographic grain
#%end

#%option
#% key: minneighb
#% type: integer
#% answer: 3
#% description: Minimum size of moving window
#% required : yes
#% guisection: Topographic grain
#%end

#%option
#% key: maxneighb
#% type: integer
#% answer: 49
#% description: Maximum size of moving window
#% required : yes
#% guisection: Topographic grain
#%end

#%option
#% key: user_res
#% type: integer
#% answer: 0
#% description: Coarser resolution if expected ridgeline-to-channel spacing is large (meter)
#% required : no
#% guisection: Topographic grain
#%end

#%option G_OPT_F_OUTPUT
#% key: profile
#% description: Name for output TG calculation profile (path/to/name.pdf)
#% required: yes
#% guisection: Topographic grain
#%end

#%option G_OPT_F_OUTPUT
#% key: table
#% description: Name for output TG calculation table (path/to/name.csv)
#% required: yes
#% guisection: Topographic grain
#%end

#%flag
#% key: c
#% description: Creating TG maps
#% guisection: Topographic grain
#%end

#%flag
#% key: g
#% description: Create geomorphon map with TG value
#% guisection: Geomorphons map
#%end

#%option
#% key: flattg
#% type: double
#% answer: 0.7
#% description: Flatness threshold
#% guisection: Geomorphons map
#%end

#%option
#% key: disttg
#% type: integer
#% answer: 0
#% description: Flatness distance
#% guisection: Geomorphons map
#%end

#%option
#% key: skiptg
#% type: integer
#% answer: 1
#% description: Skip radius
#% guisection: Geomorphons map
#%end

#%option G_OPT_R_OUTPUT
#% key: geom_map
#% description: Name for output geomorphometric map
#% answer: <elevation>_geomorphons_<TG>
#% required: no
#% guisection: Geomorphons map
#%end

import os
import platform
import sys
import subprocess
import csv
import grass.script as grass
from grass.exceptions import CalledModuleError

def main():
    if platform.system() == 'Windows':
        try:
            import winreg
        except ImportError:
            import _winreg as winreg

        try:
            try:
                key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall', 0, winreg.KEY_READ | winreg.KEY_WOW64_64KEY)
                count = (winreg.QueryInfoKey(key)[0])-1
                while (count >= 0):
                    subkeyR = winreg.EnumKey(key, count)
                    if subkeyR.startswith('R for'):
                        count = -1
                    else:
                        count = count-1
                winreg.CloseKey(key)
                key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, str('SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\' + subkeyR), 0, winreg.KEY_READ | winreg.KEY_WOW64_64KEY)
                value = winreg.QueryValueEx(key, 'InstallLocation')[0]
                winreg.CloseKey(key)
            except:
                key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall', 0, winreg.KEY_READ | winreg.KEY_WOW64_32KEY)
                count = (winreg.QueryInfoKey(key)[0])-1
                while (count >= 0):
                    subkeyR = winreg.EnumKey(key, count)
                    if subkeyR.startswith('R for'):
                        count = -1
                    else:
                        count = count-1
                winreg.CloseKey(key)
                key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, str('SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\' + subkeyR), 0, winreg.KEY_READ | winreg.KEY_WOW64_64KEY)
                value = winreg.QueryValueEx(key, 'InstallLocation')[0]
                winreg.CloseKey(key)
            grass.message(_("R is installed!"))
            pathtor = os.path.join(value, 'bin\\Rscript')
        except:
            grass.fatal("Please install R!")

    elevation = str(options['elevation']).split('@')[0]
    incheck = grass.find_file(name=elevation, element='cell')
    if not incheck['file']:
        grass.fatal("Raster map <%s> not found" % elevation)
    grass.use_temp_region()
    grass.run_command('g.region', rast=elevation)

    user_res = int(options['user_res'])
    if user_res == 0:
        gregion = grass.region()
        res_int = int(round(gregion['nsres']))
        grass.message(_("Resolution is kept at: %i m" % res_int))
    else:
        res_int = user_res
        grass.run_command('g.region', res=res_int)
        coarse_elevation = elevation + '%' + str(user_res)
        grass.run_command('r.resample', input=elevation, output=coarse_elevation)
        elevation = coarse_elevation
        grass.message(_("Resolution changed to: %s m" % user_res))

    minneighb = int(options['minneighb'])
    maxneighb = int(options['maxneighb'])

    outpdf = str(options['profile'])
    if outpdf.split('.')[-1] != 'pdf':
        grass.fatal("File type for output TG calculation profile is not pdf")
    
    outcsv = str(options['table'])
    if outcsv.split('.')[-1] != 'csv':
        grass.fatal("File type for output TG calculation table is not csv")

    tgmaps = flags['c']

    grassversion = grass.version()
    grassversion = grassversion.version[:1]
    
    TGargs = [elevation, str(res_int), str(minneighb), str(maxneighb), outpdf, outcsv, str(int(tgmaps)), str(grassversion)]
    pyscfold = os.path.dirname(os.path.realpath(__file__))
    pathtosc = os.path.join(pyscfold, 'TG_jozsa.R')
    myRSCRIPT = [pathtor, pathtosc] + TGargs
    if not os.path.isfile(pathtosc):
        grass.fatal("Put TG calculation R script to GRASS scripts folder...")    
    
    if tgmaps:
        grass.message(_("Will create map of cell-based TG value, relative relief..."))

    grass.message(_("Starting R to calculate Topographic Grain... this may take some time..."))
    devnull = open(os.devnull, 'w')
    error = subprocess.call(myRSCRIPT, stdout=devnull, stderr=devnull)

    if error > 0:
        grass.message(_("R error log below..."))
        errorlog = os.path.join(os.path.dirname(outpdf), 'errorlog.Rout')
        Rerror = open(errorlog, 'r')
        grass.message(_(Rerror.read()))
        Rerror.close()
        grass.fatal("TG calculation failed...")
    else:
        grass.message(_("R process finished...Continue working in GRASS GIS..."))
        
    elevation = str(options['elevation']).split('@')[0]
    grass.run_command('g.region', rast=elevation)
    ## Check if creating geomorphon map flag is activated
    geom = flags['g']

    if not geom:
        grass.message(_("Not creating geomorphometric map..."))
        with open(outcsv, 'r') as csvfile:
            outcsv = csv.reader(csvfile, delimiter=',')
            for row in outcsv:
                last = row
        searchtg = int(last[1])
        if user_res != 0:
            gregion = grass.region()
            res_int = int(round(gregion['nsres']))
            multiply = int(user_res / int_res)
            searchtg = int(searchtg * multiply)
        grass.message(_("Estimated topographic grain value is %i" % searchtg))
    else:
    ## Check if r.geomorphon is installed
        if not grass.find_program('r.geomorphon', '--help'):
            grass.fatal("r.geomorphon is not installed, run separately after installation")
        else:
            ## Input for r.geomorphon
            #elevation = elevation reread above
            with open(outcsv, 'r') as csvfile:
                outcsv = csv.reader(csvfile, delimiter=',')
                for row in outcsv:
                    last = row
            searchtg = int(last[1])
            if user_res != 0:
                multiply = int(user_res / res_int)
                searchtg = int(searchtg * multiply)
            skiptg = int(options['skiptg'])
            flattg = float(options['flattg'])
            disttg = int(options['disttg'])
            geom_map = str(options['geom_map'])
            if geom_map[:11] == '<elevation>':
                geom_map = str(elevation + geom_map[11:-4] + str(searchtg))

            ## Print out settings for geomorphon mapping
            grass.message(_("Generating geomorphons map with settings below:"))
            grass.message(_("Elevation map: %s" % elevation))
            grass.message(_("Search distance: %i" % searchtg))
            grass.message(_("Skip radius: %i" % skiptg))
            grass.message(_("Flatness threshold: %.2f" % flattg))
            grass.message(_("Flatness distance: %i" % disttg))
            grass.message(_("Output map: %s" % geom_map + "    *existing map will be overwritten"))
            try:
                grass.run_command('r.geomorphon', elevation=elevation, search=searchtg, skip=skiptg, flat=flattg, dist=disttg, forms=geom_map)
            except:
                grass.run_command('r.geomorphon', dem=elevation, search=searchtg, skip=skiptg, flat=flattg, dist=disttg, forms=geom_map)
    grass.del_temp_region()

if __name__ == '__main__':
    options, flags = grass.parser()
    main()
