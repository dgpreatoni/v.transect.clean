#!/bin/bash
# imports a line transect shapefile and cleans it up
#%module
#% description: clean up a line transect path, eliminating crossings, double paths and whatever else.
#%end
#%option
#% key: input
#% type: string
#% gisprompt: old,vector,vector
#% description: Input line transect path
#% required: yes
#%end 
#%option
#% key: output
#% type: string
#% gisprompt: new,vector,vector
#% description: output, cleaned transect path
#% required: yes
#%end 
#%option
#% key: radius
#% type: integer
#% description: radius (buffer width) used to collapse transect path
#% answer: 50
#% required: no
#%end 
#%option
#% key: res
#% type: integer
#% description: raster resolution used for thinning
#% answer: 5
#% required: no
#%end 

if [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program." 1>&2
    exit 1
fi

if [ "$1" != "@ARGS_PARSED@" ] ; then
    exec g.parser "$0" "$@"
fi

# temporary stuff names here
TMPBUF=XXXBUF
TMPTHN=XXXTHN
TMPCL1=XXXCL1
TMPCL2=XXXCL2

# make 50 m buffer (with no caps)
g.message -i "buffering..."
v.buffer -c input=$GIS_OPT_INPUT output=$TMPBUF distance=$GIS_OPT_RADIUS --overwrite --qq
# size up the region to negative buffer extent, also set a small resolution (e.g. 5 m or less)
g.message -i "sizing region..."
g.region vect=$TMPBUF res=$GIS_OPT_RES
# convert buffer to raster
g.message -i "rasterizing..."
v.to.rast input=$TMPBUF output=$TMPBUF use=val value=1 --overwrite --qq
# thin out
g.message -i "thinning..."
r.thin input=$TMPBUF output=$TMPTHN --overwrite --qq
# convert back to vector (line)
r.to.vect -v input=$TMPTHN output=$TMPCL1 type=line --overwrite --qq
# ensure we have some topology
v.build -e map=$TMPCL1 option=build --qq
# further clean up topology, remove dangles
MAXDANGLE=$(($GIS_OPT_RADIUS*10))
g.message -i "max dangle is $MAXDANGLE" 
v.clean input=$TMPCL1 output=$TMPCL2 tool=rmdangle,break threshold=$MAXDANGLE --overwrite --qq
# smooth out a bit
SMOOTHTHRESH=$(($GIS_OPT_RADIUS*2))
g.message -i "smoothing threshold is $SMOOTHTHRESH"
v.generalize input=$TMPCL2 output=$GIS_OPT_OUTPUT method=hermite threshold=$SMOOTHTHRESH --qq
# clean up
g.remove -f type=vect,rast name=$TMPBUF,$TMPCL1,$TMPCl2,$TMPTHN --qq

