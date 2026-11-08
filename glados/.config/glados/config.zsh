# Any value you leave out falls back to the selected mode's default.
# `glados mode <name>` overrides GLADOS_MODE; reload with `glados reload`.

GLADOS_MODE=normal          # quiet | normal | chatty | verbose

# GLADOS_PRE_PROB=100       # % chance of a remark before a command
# GLADOS_POST_PROB=100      # % chance of a remark after a successful command
# GLADOS_RARE_ODDS=20       # a rare quote appears 1 in N successful remarks

GLADOS_NOTIFY_AFTER=0       # desktop notification for commands >= N seconds (0 = off)
GLADOS_LOG=0                # 1 = journal commands to ~/.local/state/glados/session.log
# (commands may contain secrets - leave off unless needed)
