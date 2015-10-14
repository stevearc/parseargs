# parseargs
Bash utility for parsing commandline arguments inspired by [docopt](http://docopt.org/)

Example:
```bash
# Set the USAGE environment variable
USAGE="$0 <required_arg> [<optional_arg>] [<opt_repeating_arg>...]

Options:
  -s                   Short flag
  -a ARG               Short arg
  --long               Long flag
  --longarg=LARG       Long arg
  -f, --flag           Short & long flag
  -r RARG, --arg=RARG  Short & long arg
"

source parseargs.sh
parseargs "$@"
# Now all the args are set as environment variables
echo "Required arg: $REQUIRED_ARG"
[ -n "$OPTIONAL_ARG" ] && echo "Optional arg: $OPTIONAL_ARG"
[ -n "$OPT_REPEATING_ARG" ] && echo "Optional repeating arg: $OPT_REPEATING_ARG"
[ -n "$S" ] && echo "short flag set"
[ -n "$ARG" ] && echo "short arg set: $ARG"
[ -n "$LONG" ] && echo "long flag set"
[ -n "$LARG" ] && echo "long arg set: $LARG"
[ -n "$FLAG" ] && echo "short/long flag set"
[ -n "$RARG" ] && echo "short/long arg set: $RARG"
```

You can also pass the usage string in directly if you'd prefer not to set `USAGE`:
```bash
myusage="$0 ..."
parseargs "$myusage" "$@"
```
