# /etc/profile.d/00-env-sanitize.sh

unset BASH_ENV
unset ENV
unset GCONV_PATH
unset IFS
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset PERL5LIB
unset PYTHONPATH

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
export PATH

umask 077
