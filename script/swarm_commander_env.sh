#!/usr/bin/env sh
export INSTALL_SPACE=/opt/sasc
. ${INSTALL_SPACE}/venv3/bin/activate
. ${INSTALL_SPACE}/setup.sh
export PYTHONPATH=$PYTHONPATH:${INSTALL_SPACE}/venv3/lib/python3.5/site-packages:/usr/lib/python3/dist-packages
exec "$@"
