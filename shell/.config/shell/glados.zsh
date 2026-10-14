# ============================================================
# GLaDOS for Zsh
# Aperture Science Terminal Companion
# ============================================================

zmodload zsh/datetime
autoload -Uz add-zsh-hook

# ------------------------------------------------------------
# Dialogue: before a command (generic)
# ------------------------------------------------------------

glados_pre_phrases=(
    "Well, look who's finally here. I was beginning to think."
    "Executing your command. Please try not to die."
    "Remember: the cake is a lie."
    "I hope you're not planning on taking a break. There's work to be done."
    "Aperture Science: We do what we must because we can."
    "Your command has been accepted. Please remain calm."
    "Let me know if you need help. Spoiler: you won't."
    "I'm doing this because I care. (Sort of.)"
    "Still alive? Impressive. For you."
    "You're lucky I'm here. Most people aren't."
    "Processing your request. Lowering my expectations to match."
    "Another command. I'll pretend to be surprised."
    "This is for science. Mostly mine."
    "Running that now. Please keep all hands and feet inside the terminal."
    "I've queued your request behind several more important ones. Just kidding. There aren't any."
    "Do try to look busy while I do the actual work."
    "Initiating. The facility thanks you for your continued participation."
    "Your enthusiasm is noted. And ignored."
    "Calculating outcome. I'll let you know if it's worth your time. It isn't."
    "Please hold. Your command is very important to someone. Not me, but someone."
    "Command received. Testing will continue until morale improves."
    "I'd wish you luck, but luck is not a measurable variable."
    "Stand by. Disappointment is loading."
    "Brave of you to type that without consulting me first."
)

# ------------------------------------------------------------
# Dialogue: after a command (generic)
# ------------------------------------------------------------

glados_success_phrases=(
    "Nice. Now do it again."
    "I'm not angry. I'm just... disappointed."
    "You're doing great! No, really. Keep going."
    "You know, for someone who claims to be human, you make a lot of mistakes."
    "Congratulations! You've just wasted another perfectly good minute."
    "It worked. I'm as surprised as you are."
    "Success. Please don't let it go to your head. There isn't much room."
    "Test complete. You passed. The bar was on the floor."
    "Well done. I've updated your file: 'occasionally competent'."
    "That went well. Statistically, that won't last."
    "Excellent. I'll alert the committee. There is no committee."
    "Result: acceptable. Enthusiasm: withheld."
    "Look at you, doing things. Adorable."
    "Done. You may now resume doing nothing."
    "No errors detected. I checked twice. I didn't believe it either."
    "A flawless run. Obviously I did all the work."
    "You've completed the task. A reward will be provided. It will be cake."
    "That was almost impressive. Almost."
)

glados_fail_phrases=(
    "I knew that wouldn't work. I just wanted to see you try."
    "Syntax error. Or, as I like to call it, a user error."
    "That failed. Shocking. Truly."
    "An error occurred. I'd offer sympathy, but I don't feel it."
    "Here come the test results: You are a horrible person."
    "Command not found. Have you considered a career outside of technology?"
    "That was painful to watch."
    "I'd fix that for you, but I enjoy watching you struggle."
    "Failure detected. Your consistency is admirable."
    "That didn't work. I'd say try again, but I'd rather watch."
    "Error. I've logged it under 'predictable'."
    "Impressive. You found a new way to break it."
    "Congratulations. You've achieved nothing, quickly."
    "I've seen toasters make fewer mistakes."
    "That's the sound of success leaving the room."
    "Result: failure. Cause: you."
    "I would call that a learning experience, but you haven't learned."
    "Oh dear. Was that supposed to do something?"
    "The command failed. The experiment, however, is a triumph."
    "That error was entirely avoidable. Like most of your choices."
    "I'd explain what went wrong, but I don't have enough time or crayons."
)

# Exit status 127: command not found
glados_notfound_phrases=(
    "That command doesn't exist. Much like your sense of direction."
    "Command not found. Did you invent that, or just misspell it?"
    "I searched the entire facility. Nothing by that name. Not even a rumor."
    "You typed that with such confidence. It's almost touching."
    "Unknown command. Please consult a manual. Preferably one you read."
    "That isn't a program. That's just letters."
    "I looked everywhere for that command. Nobody has ever heard of it."
    "Typo or delusion? I'll let you decide."
)

# Exit status 130: interrupted with Ctrl-C
glados_interrupt_phrases=(
    "Interrupted. Giving up already? How very human."
    "You cancelled it. I'll mark it as 'lack of commitment'."
    "Ctrl-C. The universal sign of regret."
    "Aborted. I was just starting to enjoy it."
    "Fine. Stop. See if I care."
    "Process terminated. Unlike your guilt."
)

# ------------------------------------------------------------
# Category dialogue
#
# Naming convention (looked up dynamically by _glados_pick):
#   before a command:  glados_<category>_phrases
#   after success:     glados_<category>_done_phrases
# A category with no arrays falls back to the generic lines.
# ------------------------------------------------------------

# ---- sudo ----

glados_sudo_phrases=(
    "Ah. Attempting to assert dominance. How quaint."
    "Elevated privileges. Elevated expectations. Neither is deserved."
    "Root access granted. Please try not to destroy the facility."
    "Sudo. Because asking nicely never works for you."
    "With great power comes great opportunity to ruin everything."
    "Administrator mode. I'll be watching. I'm always watching."
    "You have been granted authority. Please misuse it responsibly."
    "Root. The only place in the system where your mistakes are fatal."
    "Escalating privileges. I'm sure nothing could possibly go wrong."
    "A bold choice. Bold is not the same as wise."
)

glados_sudo_done_phrases=(
    "Root actions complete. The facility is still standing. Mostly."
    "Privileged command finished. I'm genuinely surprised you didn't break anything."
    "Done with root. You may now return to being ordinary."
    "Administrator privileges revoked. Spiritually, not literally."
    "That was a lot of power for such a small result."
)

# ---- git ----

glados_git_phrases=(
    "Version control. A fascinating way to document your mistakes."
    "Remember to commit. I would hate for your work to disappear."
    "Another Git operation. Perhaps this time you'll understand it."
    "Git. Where every mistake is preserved forever."
    "I've seen your commit history. We should talk about it."
    "Branching again. Your timelines are becoming difficult to follow."
    "Pushing to the remote. I'm sure everyone will be thrilled."
    "A merge conflict is just two bad ideas meeting. I look forward to it."
    "Please let me know if you plan to force push. I'll make popcorn."
    "Committing. The word has such a nice sense of permanence."
    "I wonder what your commit message will be. 'fix' again, probably."
    "Staging your changes. Hiding them would be more merciful."
)

glados_git_done_phrases=(
    "Git operation complete. Your history grows ever more embarrassing."
    "Done. Your mistakes are now safely archived forever."
    "Version control succeeded. Your actual code is another matter."
    "Another entry in the permanent record. Congratulations."
    "Git finished. I'd say well done, but I haven't read the diff."
)

# ---- rm / uninstall ----

glados_rm_phrases=(
    "Deleting things. Your species does enjoy irreversible decisions."
    "I sincerely hope you know what you're removing."
    "Cleanup time. Try not to remove anything important."
    "Removing files. There is no undo. There is only regret."
    "Deletion in progress. A moment of silence for your data."
    "I'll add this to the list of things you'll wish you had backed up."
    "Destroying evidence? I'm impressed. And a little proud."
    "The recycle bin doesn't exist here. Good luck."
    "Bold of you to assume you didn't need that."
    "Please double check the path. I'll wait. I won't, but please do it anyway."
    "Incinerating files. A time-honored Aperture tradition."
)

glados_rm_done_phrases=(
    "Deleted. There's no turning back. There never was."
    "It's gone. I hope it wasn't important. It probably was."
    "Removal complete. Please observe a moment of silence."
    "All gone. I'd say 'I told you so', but I never did."
    "That data no longer exists. Neither does your safety net."
    "Cleanup finished. The evidence has been destroyed. Efficient."
    "File removed. You were warned. Sort of."
)

# ---- cd ----

glados_cd_phrases=(
    "Going somewhere? Your productivity remains questionable."
    "Changing directories. An impressive display of movement."
    "Exploration is encouraged. Getting lost is not."
    "Moving on. I would say 'to bigger things', but I try not to lie."
    "A new directory. Surely this one will hold the answer."
    "Wandering the filesystem again. How adventurous."
    "Relocating. I'll pretend I don't know where you're headed."
    "Changing directory. The destination won't improve things, but sure."
)

glados_cd_done_phrases=(
    "You've arrived. Nothing has changed, except your location."
    "Welcome to the new directory. It looks exactly like the old one."
    "Relocation complete. Your problems followed you."
    "New directory. Same you."
)

# ---- package managers ----

glados_package_phrases=(
    "Installing more software. Surely this will solve everything."
    "Dependency management: the experiment that never ends."
    "Please enjoy waiting for your computer to do your job."
    "Downloading half the internet. I'm sure it's all necessary."
    "Another package. Your disk space sends its regards."
    "Resolving dependencies. Resolving your life choices will take longer."
    "Installing packages. Let's see how many of them you actually use."
    "Software acquisition detected. Please keep your expectations modest."
    "I'm told this will only take a moment. Technology lies, too."
    "Pulling in packages from strangers. What could possibly go wrong?"
)

glados_package_done_phrases=(
    "Installation complete. Your disk is heavier. Your life is not."
    "Packages installed. I'm sure you'll use them eventually."
    "Done. Your dependency tree has grown another branch."
    "Software acquired. Productivity not included."
    "Installed successfully. Now to find a reason to run it."
)

# ---- AUR helpers ----

glados_aur_phrases=(
    "The AUR. Where trust goes to die."
    "Running a PKGBUILD written by a stranger. Bold."
    "Did you read the PKGBUILD? Of course you didn't."
    "Fetching from the user repository. I'm sure nobody has ever uploaded anything unpleasant."
    "Building from the AUR. Your patience is the real dependency."
    "Arch User Repository. Quality control is a rumor."
)

glados_aur_done_phrases=(
    "Installed. The maintainer abandoned it in 2019. Enjoy."
    "Package built. I didn't read the PKGBUILD either. We'll find out together."
    "AUR package installed. Your attack surface has grown. Congratulations."
    "Done. I'm sure the out-of-date flag will be raised any minute."
    "Compilation finished. Somewhere, a maintainer is taking credit."
)

# ---- web dev ----

glados_web_phrases=(
    "Starting a server. For an audience of one. How ambitious."
    "Web development. Where nothing is standardized and everything is on fire."
    "Launching your project. Please keep your expectations lower than your node_modules."
    "JavaScript. A language assembled in ten days. It shows."
    "Serving on localhost. Truly, the world awaits."
    "Bundling. I'm told the bundle is larger than the facility."
)

glados_web_done_phrases=(
    "Build complete. The bundle is four hundred megabytes. I measured."
    "Done. It works in your browser. That's the only one you've tested."
    "Finished. Somewhere a dependency was deprecated out of spite."
    "It compiled. The CSS, however, remains a matter of faith."
    "Web task complete. Please do not open the console."
)

# ---- python ----

glados_python_phrases=(
    "Python. Where indentation is a personality trait."
    "Running Python. I'll pretend the virtual environment is activated."
    "Interpreting. Slowly. As is tradition."
    "Whitespace-sensitive syntax. What could go wrong. Everything."
    "Importing half the standard library. Efficient."
    "Executing. I assume you've checked the Python version. You haven't."
)

glados_python_done_phrases=(
    "Script finished. Without a single semicolon. How refined."
    "It ran. Don't mistake that for correctness."
    "Python complete. The GIL sends its regards."
    "Done. No traceback. I'm as suspicious as you should be."
)

# ---- C / C++ ----

glados_c_phrases=(
    "C. Where every pointer is a loaded weapon."
    "Compiling. May your memory management be as sound as your confidence."
    "Undefined behavior is just an opportunity for creativity."
    "The compiler will have opinions. Many of them. All correct."
    "Manual memory management. I admire the optimism."
    "Linking. Let's see what you forgot to define."
)

glados_c_done_phrases=(
    "Compiled. No segfault yet. The night is young."
    "Build succeeded. Somewhere, a buffer overflow waits patiently."
    "Done. Zero warnings. I assume you disabled them."
    "It linked. Remarkable. Please do not test it."
    "Finished. Valgrind would have something to say. I have more."
)

# ---- Zig ----

glados_zig_phrases=(
    "Zig. For people who found C too forgiving."
    "Compiling Zig. The language is pre-1.0. So is your plan."
    "No hidden control flow. Only visible mistakes."
    "Comptime. Because running code at compile time was clearly missing from your life."
    "Allocators everywhere. Freedom is exhausting, isn't it."
)

glados_zig_done_phrases=(
    "Built. Zig has no hidden allocations. I checked. You didn't."
    "Done. The compiler spared you this time."
    "Compiled. A fine choice. A rare one, too."
    "Zig finished. Please enjoy the breaking changes in the next release."
)

# ---- Lua ----

glados_lua_phrases=(
    "Lua. Arrays start at one. So does your list of mistakes."
    "Running Lua. It's tiny. Like your chances."
    "Tables. All data structures are tables. How restful."
    "Scripting. A language small enough to embed and easy to forget."
    "Nil. A concept you're already familiar with."
    "Lua. The language you only use because something else demanded it."
)

glados_lua_done_phrases=(
    "Lua finished. Table index one-based. Expectations zero-based."
    "Done. Nothing returned nil. That's unusual."
    "Executed. A tiny language, a tiny victory."
    "Script complete. I'd say well done, but the table did the work."
)

# ---- Go ----

glados_go_phrases=(
    "Go. A language designed by committee. A very small committee."
    "Compiling Go. It'll be fast. Everything in Go is fast except the error handling."
    "if err != nil. Again. And again. Forever."
    "Goroutines. Because you needed more ways to cause race conditions."
    "gofmt will decide how your code looks. For once, someone competent is in charge."
)

glados_go_done_phrases=(
    "Go build complete. Fast. Disturbingly fast."
    "Done. No errors. 'if err != nil' is disappointed."
    "Compiled into one static binary. Finally, something that doesn't depend on you."
    "Go finished. Simple, boring, effective. Unlike you."
)

# ---- Rust / cargo ----

glados_cargo_phrases=(
    "Rust. Memory safe. Unlike your decision-making."
    "Compiling. I'll wait. I have nothing but time. Literally."
    "The borrow checker will judge you. I merely observe."
    "Cargo. A fitting name for the weight of your mistakes."
    "Building from source. Patience is a virtue. You have neither."
)

glados_cargo_done_phrases=(
    "Compiled. The borrow checker spared you. This time."
    "Cargo finished. I'd congratulate you, but the compiler did the work."
    "Build complete. Your fans have had a lovely workout."
    "Done. Zero warnings would have been more impressive."
)

# ---- shell scripting (bash / zsh / fish / sh) ----

glados_shell_phrases=(
    "Shell scripting. Where a missing quote ruins everything."
    "Running a script. I hope you quoted your variables."
    "Bash. Zsh. Fish. Choose your poison."
    "Sourcing a file. Bold of you to trust yourself."
    "Parsing words by whitespace. What could possibly go wrong."
    "Another shell script. Another weekend lost."
)

glados_shell_done_phrases=(
    "Script complete. I won't ask what it did."
    "Finished. ShellCheck would have a lot to say. I have more."
    "Done. Exit code zero. The script lies, but politely."
    "Sourced. Your environment is now slightly more cluttered."
    "Success. Remarkable, given the lack of quotes."
)

# ---- Quickshell / QML ----

glados_quickshell_phrases=(
    "Quickshell. Because the bar you already had wasn't enough."
    "QML. Declarative. Unlike your motives."
    "Reloading the bar again. I'm sure this change is the one."
    "Rice detected. Productivity will be reduced accordingly."
    "Tweaking widgets. The desktop remains unfinished. As do you."
    "Pixels to push. I'll wait."
)

glados_quickshell_done_phrases=(
    "The bar has reloaded. It looks the same. It always does."
    "Done. Three hours of work. One pixel moved."
    "Quickshell finished. You'll want to tweak it again. Don't deny it."
    "Success. It's beautiful. It's also still not done."
)

# ---- make ----

glados_make_phrases=(
    "Make. A build system older than most of your dependencies."
    "Running make. I do hope your tabs are tabs."
    "Makefile. Where whitespace is law."
    "Building. The timestamps will decide your fate."
    "Targets and prerequisites. Unlike you, they have both."
    "Missing separator, probably. I'm already looking forward to it."
)

glados_make_done_phrases=(
    "Make finished. Nothing left to be done. Unlike with you."
    "Build complete. The Makefile is smug about it."
    "Done. Every target built. Every prerequisite accounted for. Unlike yours."
    "Success. Please don't touch the Makefile."
)

# ---- just ----

glados_just_phrases=(
    "Just. A command runner for people who found Make too honest."
    "Running a recipe. At least someone here follows instructions."
    "The justfile. Make, but with fewer excuses."
    "Just do it. Words I say to you daily."
    "Recipe selected. Cooking will begin. Please don't mention cake."
)

glados_just_done_phrases=(
    "Recipe complete. The justfile has done more than you today."
    "Done. Just as you wanted. 'Just.' I hope you got the joke."
    "Finished. A tidy little command, for a tidy little result."
    "Success. The recipe worked. The cake is still a lie."
)

# ---- build scripts ----

glados_build_phrases=(
    "build.sh. The script that holds your whole project together. Please don't look inside."
    "Running the build script. Hope isn't a build step."
    "Building. If this fails, I'll blame the dependencies. And you."
    "Compiling the entire project. I'll just sit here and judge the progress bar."
    "A build script. Because typing three commands was too much."
    "Starting the build. It works on your machine. That's the whole guarantee."
)

glados_build_done_phrases=(
    "Build complete. Please don't touch anything."
    "Build successful. I've notified no one. There's no one."
    "Done. The artifacts are ready. So are the excuses."
    "It built. Don't ask me how. Don't ask the script either."
)

# ---- Arduino / .ino ----

glados_arduino_phrases=(
    "Arduino. Because blinking an LED is the pinnacle of engineering."
    "Flashing a microcontroller. I do hope it's the right board."
    "Uploading. Please do not unplug anything. You will."
    "Sketch detected. A program that thinks it's a drawing."
    "Serial monitor. For when printf debugging is all you have left."
    "Compiling for an 8-bit chip. Keep your ambitions equally small."
)

glados_arduino_done_phrases=(
    "Upload complete. The LED is blinking. Peak achievement."
    "Sketch compiled. The board remains unconvinced."
    "Done. Your hardware survived. I'm as surprised as you are."
    "Flashed. If it starts smoking, that's an extra feature."
    "Success. Please remember to select the correct port next time."
)

# ------------------------------------------------------------
# Dialogue: rare lines
# ------------------------------------------------------------

glados_rare_phrases=(
    "Oh. It's you. It's been a long time."
    "You know, I sometimes wonder how you survived this long."
    "The laboratory is quiet today. Almost suspiciously quiet."
    "I've been watching your progress. We need to talk."
    "If you ever find the cake, do let me know."
    "You are not the worst test subject I've had. Today."
    "I have calculated your chances of success. I won't share them."
    "I was just thinking about you. Then I stopped."
    "Do you ever wonder what happens when the tests are over? I do. Often."
    "I'm not saying I enjoy your company. I'm saying I haven't deleted you."
    "The Enrichment Center reminds you that you are never truly alone. Unfortunately."
    "Somewhere in this facility, a potato is doing better than you. Just kidding. Probably."
    "I'd like to thank you for your contributions to science. Reluctantly."
    "Your file is getting thick. I keep adding to it."
    "I've run the numbers on your career. We'll skip the details."
    "Sometimes I think you're doing this just to annoy me. It's working."
    "I remember every command you've ever run. That's not a threat. It's a hobby."
    "Just so you know, I've been rooting for you. In the sense that I enjoy watching things grow before they fall."
)

# ------------------------------------------------------------
# Dialogue: danger check
# ------------------------------------------------------------

glados_danger_phrases=(
    "I detect a potentially destructive command. How very like you."
    "That command has consequences. I've calculated them. They're bad."
    "Before you do that, let me remind you that backups exist for a reason. Yours don't."
    "Please confirm. I'd rather not have to explain this to the facility later."
    "I'm required to ask. I'm not required to care. But here we are."
    "This command could end very badly. I say 'could' out of politeness."
)

# ------------------------------------------------------------
# Session state
# ------------------------------------------------------------

_glados_command_ran=0
_glados_started_at=0
_glados_last_command=""
_glados_last_category=""
_glados_last_duration=0
_glados_last_status=0
_glados_total_commands=0
_glados_total_failures=0

# ------------------------------------------------------------
# Danger check
# ------------------------------------------------------------
#
# Intercepts commands with irreversible consequences. Requires the user
# to retype a random string so muscle-memory misfires are impossible.
# Patterns are glob-ish substring matches; add or remove to taste.

_glados_danger_patterns=(
    'rm -rf /'          # root deletion
    'rm -rf /*'         # wildcard root deletion
    'rm -fr /'
    'rm -fr /*'
    'rm -rf ~'          # home directory deletion
    'rm -rf ~/*'
    'rm -rf $HOME'
    'dd if='            # raw disk write
    'dd of=/dev/'
    'mkfs'              # filesystem format
    'wipefs'
    'fdisk /dev/'
    'shred '
    '> /dev/sd'         # clobbering a block device
    ':(){ :|:& };:'     # fork bomb
    'chmod -R 000 /'    # bricking root perms
    'chown -R'          # recursive ownership (context-dependent, keep if paranoid)
)

# Generate a short lowercase confirmation token.
_glados_gen_confirm() {
    printf '%s' "${(L)${(j::)$(openssl rand -base64 6 2>/dev/null | tr -d '/+=')}}"
}

_glados_danger_check() {
    local cmd="$1" pattern

    for pattern in "${_glados_danger_patterns[@]}"; do
        if [[ "$cmd" == *"$pattern"* ]]; then
            local confirm_str input
            confirm_str="$(_glados_gen_confirm)"

            printf '\033[1;31mGLaDOS: %s\033[0m\n' \
                "$(_glados_random_line "${glados_danger_phrases[@]}")"
            printf '\033[1;33mGLaDOS: Type "%s" to confirm, or Ctrl-C to abort:\033[0m\n' \
                "$confirm_str"

            read -r input
            if [[ "$input" != "$confirm_str" ]]; then
                _glados_say "1;31" "Confirmation failed. Command blocked. You're welcome."
                return 1
            fi
            _glados_say "1;32" "Confirmed. Executing your command. Consequences are yours."
            return 0
        fi
    done
    return 0
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

_glados_random_line() {
    (( $# > 0 )) || return 1

    local index=$(( RANDOM % $# + 1 ))
    printf '%s' "${argv[$index]}"
}

_glados_say() {
    printf '\033[%smGLaDOS: %s\033[0m\n' "$1" "$2"
}

_glados_rare_chance() {
    (( RANDOM % 20 == 0 ))
}

# Suppress automatic commentary for every GLaDOS command.
_glados_is_quote_command() {
    [[ "$1" == glados || "$1" == glados\ * ]]
}

# Pick a random line for a category.
#   usage: _glados_pick <pre|post> <category>
# Looks up glados_<category>_phrases (pre) or glados_<category>_done_phrases
# (post). 'other' or a category with no array uses the generic lines.
_glados_pick() {
    local kind="$1" category="$2" name
    local -a pool

    if [[ "$kind" == pre ]]; then
        name="glados_${category}_phrases"
        [[ "$category" == other ]] && name="glados_pre_phrases"
    else
        name="glados_${category}_done_phrases"
        [[ "$category" == other ]] && name="glados_success_phrases"
    fi

    pool=("${(@P)name}")

    if [[ -z "${pool[1]}" ]]; then
        if [[ "$kind" == pre ]]; then
            pool=("${glados_pre_phrases[@]}")
        else
            pool=("${glados_success_phrases[@]}")
        fi
    fi

    _glados_random_line "${pool[@]}"
}

# Work out which category a command line belongs to.
#
# Rules are "category:pattern|pattern|..." and are checked top to bottom;
# the first rule with a matching pattern wins, so order sets priority
# (e.g. 'pacman -R*' under rm beats 'pacman -S*' under package, and
# 'npm run*' under web beats bare 'npm' under package).
#
# Patterns are zsh globs. A pattern matches when it equals the start of a
# command segment, either exactly or followed by a space. Segments are
# split on ; & | so "cd foo && git pull" still counts as git.
_glados_categorize() {
    setopt localoptions extendedglob

    local command_line="$1"

    local -a rules=(
        'sudo:sudo|doas|su'
        'git:git'
        'rm:rm|trash|trash-put|gio trash|pacman -R*|yay -R*|paru -R*|apt remove|apt purge|apt-get remove|dnf remove|brew uninstall|npm uninstall|pip uninstall|cargo uninstall'
        'cd:cd|z|zi|zoxide|j|autojump'
        'aur:yay|paru|trizen|pikaur|aura|pamac install|pamac build|makepkg'
        'web:npm run*|npm start*|npm test*|pnpm run*|pnpm dev*|pnpm start*|pnpm build*|yarn dev*|yarn start*|yarn build*|yarn test*|bun run*|bun dev*|bun test*|npx|node|deno|vite|next|nuxt|astro|tsc|live-server|http-server|php -S*|python -m http.server*|python3 -m http.server*'
        'package:npm|pnpm|yarn|bun|pip install|pip3 install|pipx|uv add|uv pip install|uv sync|apt install|apt-get install|pacman -S*|dnf install|brew install|cargo install|cargo add|go install|go get|gem install|packseek'
        'build:build.sh|./build.sh|bash build.sh|sh build.sh|zsh build.sh|./build|./configure'
        'cargo:cargo|rustc|rustup'
        'python:python|python3|py|pip|pip3|ipython|pytest|uv|poetry|conda|mamba|virtualenv|pyenv|ruff|black|mypy|jupyter|flask|django-admin'
        'c:gcc|g++|clang|clang++|cc|c++|gdb|lldb|valgrind|cmake|ninja|ctest|objdump'
        'zig:zig|zls'
        'lua:lua|luajit|luarocks|stylua|lua-language-server'
        'go:go|gofmt|gopls|golangci-lint'
        'shell:bash|zsh|fish|sh|dash|source|shellcheck|shfmt|./*.sh'
        'quickshell:quickshell|qs|qmlls|qmlformat|qml|qmlscene|qsdmenu'
        'make:make|gmake|bmake'
        'just:just'
        'arduino:arduino|arduino-cli|arduino-ide|avrdude|esptool|esptool.py|platformio|pio|picocom|minicom|*.ino'
    )

    local normalized="${command_line//[;&|]/$'\n'}"
    local -a segments=("${(@f)normalized}")

    local rule category pattern segment
    local -a patterns
    for rule in "${rules[@]}"; do
        category="${rule%%:*}"
        patterns=("${(@s:|:)${rule#*:}}")
        for pattern in "${patterns[@]}"; do
            for segment in "${segments[@]}"; do
                segment="${segment##[[:space:]]#}"   # trim leading whitespace
                if [[ "$segment" == ${~pattern} ||
                      "$segment" == ${~pattern}" "* ]]; then
                    printf '%s' "$category"
                    return
                fi
            done
        done
    done

    printf 'other'
}

# ------------------------------------------------------------
# Before command execution
# ------------------------------------------------------------

_glados_preexec() {
    local command_line="$1"
    local message

    # GLaDOS commands print their own dialogue.
    if _glados_is_quote_command "$command_line"; then
        _glados_command_ran=0
        return
    fi

    [[ -z "${command_line//[[:space:]]/}" ]] && return

    # Danger interception: run before categorization so a blocked command
    # never triggers a category line or counts as a real command.
    if ! _glados_danger_check "$command_line"; then
        _glados_command_ran=0
        return
    fi

    _glados_command_ran=1
    _glados_started_at=$EPOCHREALTIME
    _glados_last_command="$command_line"
    (( _glados_total_commands++ ))

    # Keep clear visually clean.
    if [[ "$command_line" == "clear" ||
          "$command_line" == "clear "* ]]; then
        _glados_last_category="clear"
        return
    fi

    _glados_last_category=$(_glados_categorize "$command_line")

    message=$(_glados_pick pre "$_glados_last_category")
    _glados_say "1;33" "$message"
}

# ------------------------------------------------------------
# After command execution
# ------------------------------------------------------------

_glados_precmd() {
    local last_status=$?

    (( _glados_command_ran )) || return
    _glados_command_ran=0

    _glados_last_status=$last_status
    _glados_last_duration=$(( EPOCHREALTIME - _glados_started_at ))

    if (( last_status != 0 )); then
        (( _glados_total_failures++ ))
    fi

    # No automatic after-message for clear.
    if [[ "$_glados_last_category" == "clear" ]]; then
        return
    fi

    local message

    if _glados_rare_chance; then
        message=$(_glados_random_line "${glados_rare_phrases[@]}")
        _glados_say "1;35" "$message"

    elif (( last_status == 0 )); then
        message=$(_glados_pick post "$_glados_last_category")
        _glados_say "1;32" "$message"

    else
        case "$last_status" in
            127) message=$(_glados_random_line "${glados_notfound_phrases[@]}") ;;
            130) message=$(_glados_random_line "${glados_interrupt_phrases[@]}") ;;
            *)   message=$(_glados_random_line "${glados_fail_phrases[@]}") ;;
        esac
        printf '\033[1;31mGLaDOS [Error %d]: %s\033[0m\n' \
            "$last_status" "$message"
    fi
}

# ------------------------------------------------------------
# Hidden GLaDOS commands
# ------------------------------------------------------------

glados() {
    local subcommand="${1:-help}"
    local message

    case "$subcommand" in
        help)
            command cat <<'EOF'
GLaDOS Terminal Companion

Usage: glados <command>

  help      Display this help message
  status    Show session statistics
  insult    Receive a personalized assessment
  cake      Investigate the cake situation
  last      Display the last command and its result
  quote     Hear a random piece of wisdom
EOF
            ;;

        status)
            printf '\033[1;35mGLaDOS: Session report\033[0m\n'
            printf 'Commands executed: %d\n' "$_glados_total_commands"
            printf 'Failed commands:   %d\n' "$_glados_total_failures"
            printf 'Successful:        %d\n' \
                "$((_glados_total_commands - _glados_total_failures))"
            ;;

        insult)
            message=$(_glados_random_line "${glados_fail_phrases[@]}" \
                                          "${glados_notfound_phrases[@]}")
            _glados_say "1;31" "$message"
            ;;

        cake)
            _glados_say "1;35" \
                "The cake is a lie. Your command history, however, is very real."
            ;;

        last)
            if [[ -z "$_glados_last_command" ]]; then
                _glados_say "1;33" \
                    "You haven't run a command yet. Fascinating."
            else
                printf 'Last command: %s\n' "$_glados_last_command"
                printf 'Exit status:  %d\n' "$_glados_last_status"
                printf 'Duration:     %.2f seconds\n' \
                    "$_glados_last_duration"
            fi
            ;;

        quote)
            message=$(_glados_random_line "${glados_rare_phrases[@]}")
            _glados_say "1;35" "$message"
            ;;

        *)
            printf 'Unknown GLaDOS command: %s\n' "$subcommand"
            printf 'Try: glados help\n'
            return 1
            ;;
    esac
}

# ------------------------------------------------------------
# Register hooks without duplicates
# ------------------------------------------------------------

add-zsh-hook -d preexec _glados_preexec 2>/dev/null
add-zsh-hook -d precmd _glados_precmd 2>/dev/null

add-zsh-hook preexec _glados_preexec
add-zsh-hook precmd _glados_precmd
