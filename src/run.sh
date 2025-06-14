# MIT License
# 
# Copyright (c) 2025 JustStudio. <https://juststudio.is-a.dev/>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#!/bin/bash
ERRORS_FILE="$GITHUB_ACTION_PATH/data/codes.json"
CONFIG_FILE="just.config.js"
CONFIG_DATA="just.config.json"
source $GITHUB_ACTION_PATH/src/modules/errmsg.sh
if [ "$INPUT_PATH" == ""]; then
  INPUT_PATH="."
elif [ -z "$INPUT_PATH" ]; then
  INPUT_PATH="."
fi

VERSION=$(echo "$GITHUB_ACTION_PATH" | grep -oP '(?<=/v)[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?')
msg1=$(_justMessage "Running Just an Ultimate Site Tool v$VERSION")
msg2=$(_justMessage "Installing Node.js")
msg3=$(_justMessage "Installed Node.js")
msg4=$(_justMessage "Postprocessing completed")
msg5=$(_justMessage "Generating completed")
msg6=$(_justMessage "Compressing completed")
msg9=$(_justMessage "Generating completed")
echo "$msg1"

installNodejs() {
    echo "$msg2"
    sudo apt update -qq && sudo apt install -y nodejs npm > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        local ERROR_MESSAGE=$(ErrorMessage "run.sh" "0205")
        echo "$ERROR_MESSAGE"
        sudo apt update
        sudo apt install -y nodejs npm
    fi
    echo "$msg3"
}

if [ -f "$CONFIG_DATA" ]; then
    ERROR_MESSAGE=$(ErrorMessage "run.sh" "0113")
    echo "$ERROR_MESSAGE" && exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    ERROR_MESSAGE=$(ErrorMessage "run.sh" "0108")
    echo "$ERROR_MESSAGE" && exit 1
fi

CONFIG_JSON=$(node -e "console.log(JSON.stringify(require('./just.config.js')));")
if [ $? -ne 0 ]; then
    ERROR_MESSAGE=$(ErrorMessage "run.sh" "0109")
    echo "$ERROR_MESSAGE" && exit 1
fi
echo "Parsed just.config.js module.exports: $CONFIG_JSON" # debug
echo "$CONFIG_JSON" > "$CONFIG_DATA"

if [ -z "$(echo "$CONFIG_JSON" | jq -r '.module.exports')" ]; then
    ERROR_MESSAGE=$(ErrorMessage "run.sh" "0112")
    echo "$ERROR_MESSAGE" && exit 1
fi

TYPE=$(echo "$CONFIG_JSON" | jq -r '.type')
if [ -z "$TYPE" ]; then
    ERROR_MESSAGE=$(ErrorMessage "run.sh" "0110")
    echo "$ERROR_MESSAGE" && exit 1
fi

if [[ "$TYPE" != "postprocessor" && "$TYPE" != "redirector" && "$TYPE" != "compressor" && "$TYPE" != "generator" ]]; then
    ERROR_MESSAGE=$(ErrorMessage "run.sh" "0111")
    echo "$ERROR_MESSAGE" && exit 1
fi

_just_d="no" && \
if [[ "$TYPE" != "compressor" && ! ( "$TYPE" == "generator" && "$INPUT_PATH" != "." ) ]]; then
    if [ -d "deploy" ]; then
        ERROR_MESSAGE=$(ErrorMessage "important_dirs" "0106")
        echo "$ERROR_MESSAGE" && exit 1
    fi
    if [ -d "_just_data" ]; then
        ERROR_MESSAGE=$(ErrorMessage "important_dirs" "0107")
        echo "$ERROR_MESSAGE" && exit 1
    fi
    mkdir -p deploy
    mkdir -p _just_data
elif [ "$TYPE" == "generator" ]; then
    JDD=$(echo "$INPUT_PATH/_just_data" | sed 's#//*#/#g')
    _just_dir=$(echo "$INPUT_PATH/_just" | sed 's#//*#/#g')
    if [ -d "$JDD" ]; then
        ERROR_MESSAGE=$(ErrorMessage "important_dirs" "0125")
        echo "$ERROR_MESSAGE" && exit 1
    fi
    if [ -d "$_just_dir" ]; then
        ERROR_MESSAGE=$(ErrorMessage "important_dirs" "0125")
        echo "$ERROR_MESSAGE" && exit 1
    fi
    mkdir -p "$JDD"
    mkdir -p "$_just_dir"
    _just_d="yes"
fi

if [ "$TYPE" == "postprocessor" ]; then
    set -e
    postprocessor_checks=$(bash $GITHUB_ACTION_PATH/src/postprocessor/checks.sh 2>&1) || {
        error_code=$?
        if [ $error_code -eq 1 ]; then
            ERROR_MESSAGE=$(ErrorMessage "postprocessor/checks.sh" "0100" "$postprocessor_checks")
            if [ "$postprocessor_checks" == "0101" ]; then 
                ERROR_MESSAGE=$(ErrorMessage "postprocessor/checks.sh" "0101")
            fi
            echo "$ERROR_MESSAGE" && exit 1
        fi
    } && \
    bash $GITHUB_ACTION_PATH/src/postprocessor/prepare_deployment.sh && \
    bash $GITHUB_ACTION_PATH/src/postprocessor/create_api_endpoints.sh && \
    bash $GITHUB_ACTION_PATH/src/postprocessor/modify_deployment.sh && \
    bash $GITHUB_ACTION_PATH/src/postprocessor/override_deployment.sh && \
    installNodejs && \
    node $GITHUB_ACTION_PATH/src/compress.js "deploy" && \
    bash $GITHUB_ACTION_PATH/src/postprocessor/build_map.sh && \
    echo "$msg4"
elif [ "$TYPE" == "redirector" ]; then
    mkdir -p deploy/_just
    installNodejs && \
    bash $GITHUB_ACTION_PATH/src/redirect/checks.sh && \
    node $GITHUB_ACTION_PATH/src/redirect/index.js && \
    echo "$msg5"
elif [ "$TYPE" == "compressor" ]; then
    mkdir -p deploy && \
    installNodejs && \
    node $GITHUB_ACTION_PATH/src/compress.js "$INPUT_PATH" && \
    echo "$msg6"
elif [ "$TYPE" == "generator" ]; then
    HTML=$(cat "$GITHUB_ACTION_PATH/src/documentation/templates/page.html")
    CSS=$(cat "$GITHUB_ACTION_PATH/src/documentation/templates/page.css")
    JS=$(cat "$GITHUB_ACTION_PATH/src/documentation/templates/page.js")
    if [[ -d "_just" && "$_just_d" == "no" ]]; then
        local ERROR_MESSAGE=$(ErrorMessage "important_dirs" "0121")
        echo "$ERROR_MESSAGE" && exit 1
    fi && \
    mkdir -p _just && \
    mkdir -p deploy && \
    installNodejs && \
    bash $GITHUB_ACTION_PATH/src/documentation/checks.sh && \
    node "$GITHUB_ACTION_PATH/src/documentation/index.js" "$HTML" "$CSS" "$JS" "$INPUT_PATH" "$GITHUB_REPOSITORY" "$GITHUB_REPOSITORY_OWNER" && \
    node $GITHUB_ACTION_PATH/src/compress.js "$INPUT_PATH" && \
    node "$GITHUB_ACTION_PATH/src/documentation/logs.js" "$INPUT_PATH" && \
    echo "$msg9"
fi
