# Updates Gerris from source

wdir="$HOME/.local"
gts="gts-stable"
darcs_gts="http://gerris.dalembert.upmc.fr/darcs/gts-stable"
gerris="gerris-stable"
darcs_gerris="http://gerris.dalembert.upmc.fr/darcs/gerris-stable"
gfsview="gfsview-stable"
darcs_gfsview="http://gerris.dalembert.upmc.fr/darcs/gfsview-stable"
 
## Make a python environment (Gerris needs Python 2)
if [ $(conda env list | grep -c python-gerris) -lt 1 ]; then
    conda create --name python-gerris python=2 pip
fi
source activate python-gerris

## Build Gerris
build_gts=false
build_gerris=false
build_gfsview=false
 
if ( cd $wdir/src/$gts && make -k clean && \
    ( darcs pull -a $darcs_gts | grep "No remote changes to pull in" ) ) > /dev/null 2>&1 ; then
    gts_changed=false
else
    gts_changed=true
    build_gts=true
fi
 
if $build_gts ; then
    if ( cd $wdir/src/$gts && sh autogen.sh --prefix=$wdir/local && make -k && make -k install ) \
       > $wdir/build 2>&1 ; then :
    else
	echo
        echo ============ $wdir/$gts: build failed ============
	echo
	cat $wdir/build
	exit 1
    fi
    build_gerris=true
fi
 
if ( cd $wdir/src/$gerris && make -k clean && \
    ( darcs pull -a $darcs_gerris | grep "No remote changes to pull in" ) ) > /dev/null 2>&1 ; then
    gerris_changed=false
else
    gerris_changed=true
    build_gerris=true
fi
 
if $build_gerris ; then
    if ( cd $wdir/src/$gerris && sh autogen.sh --prefix=$wdir/local && make -k && make -k install ) \
       > $wdir/build 2>&1 ; then :
    else
	echo
        echo ============ $wdir/$gerris: build failed ============
	echo
	cat $wdir/build
	exit 1
    fi
    build_gfsview=true
fi
 
if ( cd $wdir/src/$gfsview && make -k clean && \
    ( darcs pull -a $darcs_gfsview | grep "No remote changes to pull in" ) ) > /dev/null 2>&1 ; then
    gfsview_changed=false
else
    gfsview_changed=true
    build_gfsview=true
fi
 
if $build_gfsview ; then
    if ( cd $wdir/src/$gfsview && sh autogen.sh --prefix=$wdir/local && make -k && make -k install ) \
       > $wdir/build 2>&1 ; then :
    else
	echo
        echo ============ $wdir/$gfsview: build failed ============
	echo
	cat $wdir/build
	exit 1
    fi
fi