#!/usr/bin/env bash
# Copyright 2014 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This script was generated from java_stub_template.txt.  Please
# don't edit it directly.
#
# If present, these flags should either be at the beginning of the command
# line, or they should be wrapped in a --wrapper_script_flag=FLAG argument.
#
# --debug               Launch the JVM in remote debugging mode listening
# --debug=<port>        to the specified port or the port set in the
#                       DEFAULT_JVM_DEBUG_PORT environment variable (e.g.
#                       'export DEFAULT_JVM_DEBUG_PORT=8000') or else the
#                       default port of 5005.  The JVM starts suspended
#                       unless the DEFAULT_JVM_DEBUG_SUSPEND environment
#                       variable is set to 'n'.
# --main_advice=<class> Run an alternate main class with the usual main
#                       program and arguments appended as arguments.
# --main_advice_classpath=<classpath>
#                       Prepend additional class path entries.
# --jvm_flag=<flag>     Pass <flag> to the "java" command itself.
#                       <flag> may contain spaces. Can be used multiple times.
# --jvm_flags=<flags>   Pass space-separated flags to the "java" command
#                       itself. Can be used multiple times.
# --singlejar           Start the program from the packed-up deployment
#                       jar rather than from the classpath.
# --print_javabin       Print the location of java executable binary and exit.
# --classpath_limit=<length>
#                       Specify the maximum classpath length. If the classpath
#                       is shorter, this script passes it to Java as a command
#                       line flag, otherwise it creates a classpath jar.
#
# The remainder of the command line is passed to the program.

set -o posix

# Make it easy to insert 'set -x' or similar commands when debugging problems with this script.
eval "$JAVA_STUB_DEBUG"

# Prevent problems where the caller has exported CLASSPATH, causing our
# computed value to be copied into the environment and double-counted
# against the argv limit.
unset CLASSPATH

JVM_FLAGS_CMDLINE=()

# Processes an argument for the wrapper. Returns 0 if the given argument
# was recognized as an argument for this wrapper, and 1 if it was not.
function process_wrapper_argument() {
  case "$1" in
    --debug) JVM_DEBUG_PORT="${DEFAULT_JVM_DEBUG_PORT:-5005}" ;;
    --debug=*) JVM_DEBUG_PORT="${1#--debug=}" ;;
    --main_advice=*) MAIN_ADVICE="${1#--main_advice=}" ;;
    --main_advice_classpath=*) MAIN_ADVICE_CLASSPATH="${1#--main_advice_classpath=}" ;;
    --jvm_flag=*) JVM_FLAGS_CMDLINE+=( "${1#--jvm_flag=}" ) ;;
    --jvm_flags=*) JVM_FLAGS_CMDLINE+=( ${1#--jvm_flags=} ) ;;
    --singlejar) SINGLEJAR=1 ;;
    --print_javabin) PRINT_JAVABIN=1 ;;
    --classpath_limit=*)
        CLASSPATH_LIMIT="${1#--classpath_limit=}"
        echo "$CLASSPATH_LIMIT" | grep -q '^[0-9]\+$' || \
          die "ERROR: $self failed, --classpath_limit is not a number"
        ;;
    *)
      return 1 ;;
  esac
  return 0
}

die() {
  printf "%s: $1\n" "$0" "${@:2}" >&2
  exit 1
}

# Windows
function is_windows() {
  [[ "${OSTYPE}" =~ msys* ]] || [[ "${OSTYPE}" =~ cygwin* ]]
}

# macOS
function is_macos() {
  [[ "${OSTYPE}" =~ darwin* ]]
}

function available_utf8_locale() {
  # Both C.UTF-8 and en_US.UTF-8 do not cause any language-specific effects
  # when set as LC_CTYPE, but neither is certain to exist on all systems.
  #
  # https://github.com/bazelbuild/bazel/pull/17670: Note that the use of "env"
  # is important in these calls. Without "env", bash itself seems to pick up
  # the LC_CTYPE change as soon as the variable is defined and may emit a
  # warning when the locale files are not present. By using "env", bash never
  # sees the change and the 2>/dev/null redirection does the right thing.
  if [[ "$(env LC_CTYPE=C.UTF-8 locale charmap 2>/dev/null)" == "UTF-8" ]]; then
    echo "C.UTF-8"
  elif [[ "$(env LC_CTYPE=en_US.UTF-8 locale charmap 2>/dev/null)" == "UTF-8" ]]; then
    echo "en_US.UTF-8"
  fi
}

# Parse arguments sequentially until the first unrecognized arg is encountered.
# Scan the remaining args for --wrapper_script_flag=X options and process them.
ARGS=()
for ARG in "$@"; do
  if [[ "$ARG" == --wrapper_script_flag=* ]]; then
    process_wrapper_argument "${ARG#--wrapper_script_flag=}" \
      || die "invalid wrapper argument '%s'" "$ARG"
  elif [[ "${#ARGS}" -gt 0 ]] || ! process_wrapper_argument "$ARG"; then
    ARGS+=( "$ARG" )
  fi
done

# Find our runfiles tree.  We need this to construct the classpath
# (unless --singlejar was passed).
#
# Call this program X.  X was generated by a java_binary or java_test rule.
# X may be invoked in many ways:
#   1a) directly by a user, with $0 in the output tree
#   1b) via 'bazel run' (similar to case 1a)
#   2) directly by a user, with $0 in X's runfiles tree
#   3) by another program Y which has a data dependency on X, with $0 in Y's runfiles tree
#   4) via 'bazel test'
#   5) by a genrule cmd, with $0 in the output tree
#   6) case 3 in the context of a genrule
#
# For case 1, $0 will be a regular file, and the runfiles tree will be
# at $0.runfiles.
# For case 2, $0 will be a symlink to the file seen in case 1.
# For case 3, we use Y's runfiles tree, which will be a superset of X's.
# For case 4, $JAVA_RUNFILES and $TEST_SRCDIR should already be set.
# Case 5 is handled like case 1.
# Case 6 is handled like case 3.

# If we are running on Windows, convert the windows style path
# to unix style for detecting runfiles path.
if is_windows; then
  self=$(cygpath --unix "$0")
else
  self="$0"
fi

if [[ "$self" != /* ]]; then
  self="$PWD/$self"
fi

if [[ "$SINGLEJAR" != 1 || "1" == 1 ]]; then
  if [[ -z "$JAVA_RUNFILES" ]]; then
    while true; do
      if [[ -e "$self.runfiles" ]]; then
        JAVA_RUNFILES="$self.runfiles"
        break
      fi
      if [[ $self == *.runfiles/* ]]; then
        JAVA_RUNFILES="${self%.runfiles/*}.runfiles"
        break
      fi
      if [[ ! -L "$self" ]]; then
        break
      fi
      readlink="$(readlink "$self")"
      if [[ "$readlink" = /* ]]; then
        self="$readlink"
      else
        # resolve relative symlink
        self="${self%/*}/$readlink"
      fi
    done
    if [[ -n "$JAVA_RUNFILES" ]]; then
      export TEST_SRCDIR=${TEST_SRCDIR:-$JAVA_RUNFILES}
    elif [[ -f "${self}_deploy.jar" && "1" == 0 ]]; then
      SINGLEJAR=1;
    else
      die 'Cannot locate runfiles directory. (Set $JAVA_RUNFILES to inhibit searching.)'
    fi
  fi
fi

# If we are running on Windows, we need a windows style runfiles path for constructing CLASSPATH
if is_windows; then
  JAVA_RUNFILES=$(cygpath --windows "$JAVA_RUNFILES")
fi

export JAVA_RUNFILES
export RUNFILES_MANIFEST_FILE="${JAVA_RUNFILES}/MANIFEST"
export RUNFILES_MANIFEST_ONLY=

if [ -z "$RUNFILES_MANIFEST_ONLY" ]; then
  function rlocation() {
    if [[ "$1" = /* ]]; then
      echo $1
    else
      echo "$(dirname $RUNFILES_MANIFEST_FILE)/$1"
    fi
  }
else
  if ! is_macos; then
    # Read file into my_array
    oifs=$IFS
    IFS=$'\n'
    my_array=( $(sed -e 's/\r//g' "$RUNFILES_MANIFEST_FILE") )
    IFS=$oifs

    # Process each runfile line into a [key,value] entry in runfiles_array
    # declare -A is not supported on macOS because an old version of bash is used.
    declare -A runfiles_array
    for line in "${my_array[@]}"
    do
      line_split=($line)
      runfiles_array[${line_split[0]}]=${line_split[@]:1}
    done
  fi

  function rlocation() {
    if [[ "$1" = /* ]]; then
      echo $1
    else
      if is_macos; then
        # Print the rest of line after the first space
        # First, set the first column to empty and print rest of the line
        # Second, use a trick of awk to remove leading and trailing spaces.
        echo $(grep "^$1 " $RUNFILES_MANIFEST_FILE | awk '{ $1=""; print }' | awk '{ $1=$1; print }')
      else
        echo ${runfiles_array[$1]}
      fi
    fi
  }
fi

# Set JAVABIN to the path to the JVM launcher.
JAVABIN=${JAVABIN:-${JAVA_RUNFILES}/rules_java++toolchains+local_jdk/bin/java}

if [[ "$PRINT_JAVABIN" == 1 || "com.intellij.idea.Main" == "--print_javabin" ]]; then
  echo -n "$JAVABIN"
  exit 0
fi

if [[ "$SINGLEJAR" == 1 ]]; then
  CLASSPATH="${self}_deploy.jar"
  # Check for the deploy jar now.  If it doesn't exist, we can print a
  # more helpful error message than the JVM.
  [[ -r "$CLASSPATH" ]] \
    || die "Option --singlejar was passed, but %s does not exist.\n  (You may need to build it explicitly.)" "$CLASSPATH"
else
  # Create the shortest classpath we can, by making it relative if possible.
  RUNPATH="${JAVA_RUNFILES}/_main/"
  RUNPATH="${RUNPATH#$PWD/}"
  CLASSPATH="${RUNPATH}main_run_git.jar:${RUNPATH}platform/bootstrap/bootstrap.jar:${RUNPATH}platform/core-api/core.jar:${RUNPATH}platform/extensions/extensions.jar:${RUNPATH}../lib++_repo_rules+kotlinx-coroutines-core-jvm-1_10_1-intellij-4_http/file/kotlinx-coroutines-core-jvm-1.10.1-intellij-4.jar:${RUNPATH}platform/util/jdom/jdom.jar:${RUNPATH}../lib++_repo_rules+jaxen-1_2_0_http/file/jaxen-1.2.0.jar:${RUNPATH}../lib++_repo_rules+annotations-26_0_2_http/file/annotations-26.0.2.jar:${RUNPATH}platform/util/util.jar:${RUNPATH}platform/util-rt/util-rt.jar:${RUNPATH}../lib++_repo_rules+annotations-java5-24_0_0_http/file/annotations-java5-24.0.0.jar:${RUNPATH}platform/util/base/base.jar:${RUNPATH}platform/util/base/multiplatform/multiplatform.jar:${RUNPATH}../lib++_repo_rules+kotlin-stdlib-2_2_0-RC2_http/file/kotlin-stdlib-2.2.0-RC2.jar:${RUNPATH}../lib++_repo_rules+kotlinx-coroutines-debug-1_10_1-intellij-4_http/file/kotlinx-coroutines-debug-1.10.1-intellij-4.jar:${RUNPATH}../lib++_repo_rules+intellij-deps-fastutil-8_5_15-jb1_http/file/intellij-deps-fastutil-8.5.15-jb1.jar:${RUNPATH}platform/util/multiplatform/multiplatform.jar:${RUNPATH}../lib++_repo_rules+log4j-over-slf4j-1_7_36_http/file/log4j-over-slf4j-1.7.36.jar:${RUNPATH}platform/util-class-loader/util-classLoader.jar:${RUNPATH}platform/util/rt-java8/rt-java8.jar:${RUNPATH}../lib++_repo_rules+jna-platform-5_17_0_http/file/jna-platform-5.17.0.jar:${RUNPATH}../lib++_repo_rules+jna-5_17_0_http/file/jna-5.17.0.jar:${RUNPATH}../lib++_repo_rules+oro-2_0_8_http/file/oro-2.0.8.jar:${RUNPATH}../lib++_repo_rules+lz4-java-1_8_0_http/file/lz4-java-1.8.0.jar:${RUNPATH}../lib++_repo_rules+commons-compress-1_27_1_http/file/commons-compress-1.27.1.jar:${RUNPATH}../lib++_repo_rules+aalto-xml-1_3_3_http/file/aalto-xml-1.3.3.jar:${RUNPATH}../lib++_repo_rules+stax2-api-4_2_2_http/file/stax2-api-4.2.2.jar:${RUNPATH}platform/util/xmlDom/xmlDom.jar:${RUNPATH}../lib++_repo_rules+kotlinx-serialization-core-jvm-1_8_1_http/file/kotlinx-serialization-core-jvm-1.8.1.jar:${RUNPATH}../lib++_repo_rules+kotlinx-serialization-json-jvm-1_8_1_http/file/kotlinx-serialization-json-jvm-1.8.1.jar:${RUNPATH}platform/util/coroutines/coroutines.jar:${RUNPATH}../lib++_repo_rules+kotlinx-collections-immutable-jvm-0_4_0_http/file/kotlinx-collections-immutable-jvm-0.4.0.jar:${RUNPATH}platform/util/util_resources.jar:${RUNPATH}../lib++_repo_rules+commons-io-2_18_0_http/file/commons-io-2.18.0.jar:${RUNPATH}../lib++_repo_rules+commons-codec-1_18_0_http/file/commons-codec-1.18.0.jar:${RUNPATH}../lib++_repo_rules+commons-lang3-3_17_0_http/file/commons-lang3-3.17.0.jar:${RUNPATH}platform/diagnostic/diagnostic.jar:${RUNPATH}platform/util/progress/progress.jar:${RUNPATH}../lib++_repo_rules+guava-33_4_8-jre_http/file/guava-33.4.8-jre.jar:${RUNPATH}../lib++_repo_rules+failureaccess-1_0_3_http/file/failureaccess-1.0.3.jar:${RUNPATH}platform/core-api/core_resources.jar:${RUNPATH}platform/projectModel-api/projectModel.jar:${RUNPATH}jps/model-api/model.jar:${RUNPATH}platform/util/concurrency/concurrency.jar:${RUNPATH}platform/workspace/storage/storage.jar:${RUNPATH}../lib++_repo_rules+kotlin-reflect-2_2_0-RC2_http/file/kotlin-reflect-2.2.0-RC2.jar:${RUNPATH}../lib++_repo_rules+caffeine-3_2_0_http/file/caffeine-3.2.0.jar:${RUNPATH}../lib++_repo_rules+kryo5-5_6_0_http/file/kryo5-5.6.0.jar:${RUNPATH}platform/diagnostic/telemetry/telemetry.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-sdk-1_48_0_http/file/opentelemetry-sdk-1.48.0.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-api-1_48_0_http/file/opentelemetry-api-1.48.0.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-context-1_48_0_http/file/opentelemetry-context-1.48.0.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-sdk-common-1_48_0_http/file/opentelemetry-sdk-common-1.48.0.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-sdk-trace-1_48_0_http/file/opentelemetry-sdk-trace-1.48.0.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-sdk-metrics-1_48_0_http/file/opentelemetry-sdk-metrics-1.48.0.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-sdk-logs-1_48_0_http/file/opentelemetry-sdk-logs-1.48.0.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-semconv-1_30_0_http/file/opentelemetry-semconv-1.30.0.jar:${RUNPATH}platform/workspace/storage/storage_resources.jar:${RUNPATH}platform/workspace/jps/jps.jar:${RUNPATH}jps/model-impl/model-impl.jar:${RUNPATH}jps/model-impl/model-impl_resources.jar:${RUNPATH}jps/model-serialization/model-serialization.jar:${RUNPATH}jps/model-serialization/model-serialization_resources.jar:${RUNPATH}platform/workspace/jps/jps_resources.jar:${RUNPATH}platform/backend/workspace/workspace.jar:${RUNPATH}platform/projectModel-api/projectModel_resources.jar:${RUNPATH}platform/service-container/service-container.jar:${RUNPATH}platform/core-impl/core-impl.jar:${RUNPATH}../lib++_repo_rules+automaton-1_12-4_http/file/automaton-1.12-4.jar:${RUNPATH}platform/util/diff/diff.jar:${RUNPATH}platform/plugins/parser/impl/impl.jar:${RUNPATH}platform/syntax/syntax-api/syntax.jar:${RUNPATH}platform/core-impl/core-impl_resources.jar:${RUNPATH}platform/util-ex/util-ex.jar:${RUNPATH}../lib++_repo_rules+jcip-annotations-1_0_http/file/jcip-annotations-1.0.jar:${RUNPATH}../lib++_repo_rules+netty-buffer-4_2_0_RC2_http/file/netty-buffer-4.2.0.RC2.jar:${RUNPATH}../lib++_repo_rules+netty-common-4_2_0_RC2_http/file/netty-common-4.2.0.RC2.jar:${RUNPATH}../lib++_repo_rules+h2-mvstore-2_3_232_http/file/h2-mvstore-2.3.232.jar:${RUNPATH}platform/projectModel-impl/projectModel-impl.jar:${RUNPATH}../lib++_repo_rules+hash4j-0_22_0_http/file/hash4j-0.22.0.jar:${RUNPATH}platform/eel-provider/eel-provider.jar:${RUNPATH}platform/eel/eel.jar:${RUNPATH}platform/diagnostic/telemetry-impl/telemetry-impl.jar:${RUNPATH}platform/diagnostic/telemetry.exporters/telemetry.exporters.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-exporter-otlp-common-1_48_0_http/file/opentelemetry-exporter-otlp-common-1.48.0.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-exporter-common-1_48_0_http/file/opentelemetry-exporter-common-1.48.0.jar:${RUNPATH}platform/util/http/http.jar:${RUNPATH}../lib++_repo_rules+ktor-client-core-jvm-3_0_3_http/file/ktor-client-core-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-http-jvm-3_0_3_http/file/ktor-http-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-utils-jvm-3_0_3_http/file/ktor-utils-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-io-jvm-3_0_3_http/file/ktor-io-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-events-jvm-3_0_3_http/file/ktor-events-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-websocket-serialization-jvm-3_0_3_http/file/ktor-websocket-serialization-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-serialization-jvm-3_0_3_http/file/ktor-serialization-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-websockets-jvm-3_0_3_http/file/ktor-websockets-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-sse-jvm-3_0_3_http/file/ktor-sse-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-client-java-jvm-3_0_3_http/file/ktor-client-java-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+kotlinx-io-core-jvm-0_7_0_http/file/kotlinx-io-core-jvm-0.7.0.jar:${RUNPATH}../lib++_repo_rules+kotlinx-io-bytestring-jvm-0_7_0_http/file/kotlinx-io-bytestring-jvm-0.7.0.jar:${RUNPATH}../lib++_repo_rules+jackson-core-2_19_0_http/file/jackson-core-2.19.0.jar:${RUNPATH}../lib++_repo_rules+jackson-databind-2_19_0_http/file/jackson-databind-2.19.0.jar:${RUNPATH}../lib++_repo_rules+jackson-annotations-2_19_0_http/file/jackson-annotations-2.19.0.jar:${RUNPATH}../lib++_repo_rules+jackson-module-kotlin-2_19_0_http/file/jackson-module-kotlin-2.19.0.jar:${RUNPATH}../lib++_repo_rules+kotlinx-serialization-protobuf-jvm-1_8_1_http/file/kotlinx-serialization-protobuf-jvm-1.8.1.jar:${RUNPATH}platform/diagnostic/telemetry.exporters/telemetry.exporters_resources.jar:${RUNPATH}platform/diagnostic/telemetry/rt/rt.jar:${RUNPATH}../lib++_repo_rules+opentelemetry-extension-kotlin-1_48_0_http/file/opentelemetry-extension-kotlin-1.48.0.jar:${RUNPATH}../lib++_repo_rules+HdrHistogram-2_2_2_http/file/HdrHistogram-2.2.2.jar:${RUNPATH}platform/diagnostic/telemetry-impl/telemetry-impl_resources.jar:${RUNPATH}platform/projectModel-impl/projectModel-impl_resources.jar:${RUNPATH}platform/instanceContainer/instanceContainer.jar:${RUNPATH}platform/service-container/service-container_resources.jar:${RUNPATH}platform/platform-impl/ide-impl.jar:${RUNPATH}platform/platform-api/ide.jar:${RUNPATH}platform/forms_rt/java-guiForms-rt.jar:${RUNPATH}platform/remote-core/remote-core.jar:${RUNPATH}platform/credential-store/credential-store.jar:${RUNPATH}platform/platform-util-io/ide-util-io.jar:${RUNPATH}platform/platform-util-io/ide-util-io_resources.jar:${RUNPATH}platform/remote-core/remote-core_resources.jar:${RUNPATH}../lib++_repo_rules+slf4j-api-2_0_13_http/file/slf4j-api-2.0.13.jar:${RUNPATH}../lib++_repo_rules+slf4j-jdk14-2_0_13_http/file/slf4j-jdk14-2.0.13.jar:${RUNPATH}platform/ide-core/ide-core.jar:${RUNPATH}platform/core-ui/core-ui.jar:${RUNPATH}platform/util/util-ui.jar:${RUNPATH}../lib++_repo_rules+imgscalr-lib-4_2_http/file/imgscalr-lib-4.2.jar:${RUNPATH}../lib++_repo_rules+java-compatibility-1_0_1_http/file/java-compatibility-1.0.1.jar:${RUNPATH}platform/util/zip/zip.jar:${RUNPATH}../lib++_repo_rules+jbr-api-1_5_0_http/file/jbr-api-1.5.0.jar:${RUNPATH}../lib++_repo_rules+jsvg-1_3_0-jb_8_http/file/jsvg-1.3.0-jb.8.jar:${RUNPATH}platform/util/util-ui_resources.jar:${RUNPATH}platform/editor-ui-api/editor-ui.jar:${RUNPATH}platform/indexing-api/indexing.jar:${RUNPATH}platform/indexing-api/indexing_resources.jar:${RUNPATH}platform/editor-ui-api/editor-ui_resources.jar:${RUNPATH}platform/analysis-api/analysis.jar:${RUNPATH}platform/analysis-api/analysis_resources.jar:${RUNPATH}platform/settings/settings.jar:${RUNPATH}platform/kernel/shared/kernel.jar:${RUNPATH}platform/kernel/rpc/rpc.jar:${RUNPATH}fleet/rpc/rpc.jar:${RUNPATH}fleet/reporting/api/api.jar:${RUNPATH}fleet/reporting/shared/shared.jar:${RUNPATH}fleet/multiplatform.shims/multiplatform.shims.jar:${RUNPATH}../lib++_repo_rules+kotlinx-datetime-jvm-0_6_2_http/file/kotlinx-datetime-jvm-0.6.2.jar:${RUNPATH}fleet/util/core/core.jar:${RUNPATH}fleet/util/logging/api/api.jar:${RUNPATH}fleet/fastutil/fastutil.jar:${RUNPATH}../lib++_repo_rules+kotlin-codepoints-jvm-0_9_0_http/file/kotlin-codepoints-jvm-0.9.0.jar:${RUNPATH}platform/kernel/rpc/rpc_resources.jar:${RUNPATH}fleet/kernel/kernel.jar:${RUNPATH}fleet/rhizomedb/rhizomedb.jar:${RUNPATH}platform/kernel/pasta/pasta.jar:${RUNPATH}fleet/andel/andel.jar:${RUNPATH}platform/kernel/shared/kernel_resources.jar:${RUNPATH}platform/ide-core/ide-core_resources.jar:${RUNPATH}platform/progress/shared/ide-progress.jar:${RUNPATH}platform/project/shared/project.jar:${RUNPATH}platform/platform-impl/rpc/rpc.jar:${RUNPATH}platform/usageView/usageView.jar:${RUNPATH}platform/statistics/statistics.jar:${RUNPATH}../lib++_repo_rules+model-134_http/file/model-134.jar:${RUNPATH}../lib++_repo_rules+ap-validation-134_http/file/ap-validation-134.jar:${RUNPATH}platform/statistics/uploader/uploader.jar:${RUNPATH}platform/statistics/config/config.jar:${RUNPATH}../lib++_repo_rules+serialization-kotlin-134_http/file/serialization-kotlin-134.jar:${RUNPATH}../lib++_repo_rules+configuration-134_http/file/configuration-134.jar:${RUNPATH}platform/statistics/uploader/uploader_resources.jar:${RUNPATH}platform/runtime/product/product.jar:${RUNPATH}platform/runtime/repository/repository.jar:${RUNPATH}platform/ide-core/plugins/plugins.jar:${RUNPATH}../lib++_repo_rules+connection-client-134_http/file/connection-client-134.jar:${RUNPATH}platform/statistics/statistics_resources.jar:${RUNPATH}platform/ide-core-impl/ide-core-impl.jar:${RUNPATH}platform/analysis-impl/analysis-impl.jar:${RUNPATH}platform/editor-ui-ex/editor-ex.jar:${RUNPATH}platform/indexing-impl/indexing-impl.jar:${RUNPATH}../lib++_repo_rules+streamex-0_8_3_http/file/streamex-0.8.3.jar:${RUNPATH}platform/util/nanoxml/nanoxml.jar:${RUNPATH}platform/util/storages/storages.jar:${RUNPATH}platform/editor-ui-ex/editor-ex_resources.jar:${RUNPATH}../lib++_repo_rules+gson-2_13_1_http/file/gson-2.13.1.jar:${RUNPATH}platform/code-style-api/codeStyle.jar:${RUNPATH}platform/code-style-api/codeStyle_resources.jar:${RUNPATH}platform/util/text-matching/text-matching.jar:${RUNPATH}platform/analysis-impl/analysis-impl_resources.jar:${RUNPATH}../lib++_repo_rules+icu4j-77_1_http/file/icu4j-77.1.jar:${RUNPATH}platform/backend/observation/observation.jar:${RUNPATH}platform/ide-core-impl/ide-core-impl_resources.jar:${RUNPATH}platform/usageView/usageView_resources.jar:${RUNPATH}platform/project/shared/project_resources.jar:${RUNPATH}platform/progress/shared/ide-progress_resources.jar:${RUNPATH}platform/icons/icons_resources.jar:${RUNPATH}platform/icons/icons_resources_1.jar:${RUNPATH}platform/observable/observable.jar:${RUNPATH}../lib++_repo_rules+jcef-122_1_9-gd14e051-chromium-122_0_6261_94-api-1_18-251-b27_http/file/jcef-122.1.9-gd14e051-chromium-122.0.6261.94-api-1.18-251-b27.jar:${RUNPATH}platform/platform-api/ide_resources.jar:${RUNPATH}platform/lang-api/lang.jar:${RUNPATH}platform/lang-core/lang-core.jar:${RUNPATH}platform/execution/execution.jar:${RUNPATH}platform/execution/execution_resources.jar:${RUNPATH}platform/lang-core/lang-core_resources.jar:${RUNPATH}platform/lvcs-api/lvcs.jar:${RUNPATH}platform/refactoring/refactoring.jar:${RUNPATH}platform/refactoring/refactoring_resources.jar:${RUNPATH}platform/ml-api/ml.jar:${RUNPATH}../lib++_repo_rules+ml-api-86_http/file/ml-api-86.jar:${RUNPATH}platform/ml-api/ml_resources.jar:${RUNPATH}platform/lang-api/lang_resources.jar:${RUNPATH}../lib++_repo_rules+winp-1_30_1_http/file/winp-1.30.1.jar:${RUNPATH}../lib++_repo_rules+swingx-core-1_6_2-2_http/file/swingx-core-1.6.2-2.jar:${RUNPATH}../lib++_repo_rules+miglayout-swing-11_4_http/file/miglayout-swing-11.4.jar:${RUNPATH}../lib++_repo_rules+miglayout-core-11_4_http/file/miglayout-core-11.4.jar:${RUNPATH}../lib++_repo_rules+commons-imaging-1_0-RC-1_http/file/commons-imaging-1.0-RC-1.jar:${RUNPATH}../lib++_repo_rules+httpmime-4_5_14_http/file/httpmime-4.5.14.jar:${RUNPATH}../lib++_repo_rules+httpclient-4_5_14_http/file/httpclient-4.5.14.jar:${RUNPATH}../lib++_repo_rules+httpcore-4_4_16_http/file/httpcore-4.4.16.jar:${RUNPATH}platform/diff-api/diff.jar:${RUNPATH}platform/diff-api/diff_resources.jar:${RUNPATH}platform/built-in-server-api/builtInServer.jar:${RUNPATH}../lib++_repo_rules+netty-codec-http2-4_2_0_RC2_http/file/netty-codec-http2-4.2.0.RC2.jar:${RUNPATH}../lib++_repo_rules+netty-transport-4_2_0_RC2_http/file/netty-transport-4.2.0.RC2.jar:${RUNPATH}../lib++_repo_rules+netty-resolver-4_2_0_RC2_http/file/netty-resolver-4.2.0.RC2.jar:${RUNPATH}../lib++_repo_rules+netty-codec-4_2_0_RC2_http/file/netty-codec-4.2.0.RC2.jar:${RUNPATH}../lib++_repo_rules+netty-codec-base-4_2_0_RC2_http/file/netty-codec-base-4.2.0.RC2.jar:${RUNPATH}../lib++_repo_rules+netty-handler-4_2_0_RC2_http/file/netty-handler-4.2.0.RC2.jar:${RUNPATH}../lib++_repo_rules+netty-transport-native-unix-common-4_2_0_RC2_http/file/netty-transport-native-unix-common-4.2.0.RC2.jar:${RUNPATH}../lib++_repo_rules+netty-codec-http-4_2_0_RC2_http/file/netty-codec-http-4.2.0.RC2.jar:${RUNPATH}platform/built-in-server-api/builtInServer_resources.jar:${RUNPATH}../lib++_repo_rules+jackson-jr-objects-2_19_0_http/file/jackson-jr-objects-2.19.0.jar:${RUNPATH}platform/platform-util-io-impl/ide-util-io-impl.jar:${RUNPATH}../lib++_repo_rules+pty4j-0_13_8_http/file/pty4j-0.13.8.jar:${RUNPATH}../lib++_repo_rules+proxy-vole-1_1_6_http/file/proxy-vole-1.1.6.jar:${RUNPATH}../lib++_repo_rules+delight-rhino-sandbox-0_0_17_http/file/delight-rhino-sandbox-0.0.17.jar:${RUNPATH}../lib++_repo_rules+rhino-runtime-1_7_15_http/file/rhino-runtime-1.7.15.jar:${RUNPATH}../lib++_repo_rules+asm-all-9_6_1_http/file/asm-all-9.6.1.jar:${RUNPATH}../lib++_repo_rules+jsoup-1_19_1_http/file/jsoup-1.19.1.jar:${RUNPATH}platform/rd-platform-community/rd-community.jar:${RUNPATH}../lib++_repo_rules+rd-core-2025_1_1_http/file/rd-core-2025.1.1.jar:${RUNPATH}../lib++_repo_rules+rd-framework-2025_1_1_http/file/rd-framework-2025.1.1.jar:${RUNPATH}../lib++_repo_rules+rd-swing-2025_1_1_http/file/rd-swing-2025.1.1.jar:${RUNPATH}../lib++_repo_rules+rd-text-2025_1_1_http/file/rd-text-2025.1.1.jar:${RUNPATH}../lib++_repo_rules+blockmap-1_0_7_http/file/blockmap-1.0.7.jar:${RUNPATH}../lib++_repo_rules+marketplace-zip-signer-0_1_24_http/file/marketplace-zip-signer-0.1.24.jar:${RUNPATH}../lib++_repo_rules+classgraph-4_8_179_http/file/classgraph-4.8.179.jar:${RUNPATH}platform/platform-util-netty/ide-util-netty.jar:${RUNPATH}../lib++_repo_rules+jvm-native-trusted-roots-1_0_24_http/file/jvm-native-trusted-roots-1.0.24.jar:${RUNPATH}platform/code-style-impl/codeStyle-impl.jar:${RUNPATH}platform/code-style-impl/codeStyle-impl_resources.jar:${RUNPATH}platform/diagnostic/startUpPerformanceReporter/startUpPerformanceReporter.jar:${RUNPATH}platform/ijent/ijent.jar:${RUNPATH}platform/ijent/ijent_resources.jar:${RUNPATH}platform/core-nio-fs/core-nio-fs.jar:${RUNPATH}platform/core-nio-fs/core-nio-fs_resources.jar:${RUNPATH}platform/ijent/impl/impl.jar:${RUNPATH}platform/eel-impl/eel-impl.jar:${RUNPATH}platform/eel-impl/eel-impl_resources.jar:${RUNPATH}platform/ijent/impl/impl_resources.jar:${RUNPATH}platform/ijent/buildConstants/buildConstants.jar:${RUNPATH}platform/jbr/jbr.jar:${RUNPATH}platform/ui.jcef/ui.jcef.jar:${RUNPATH}platform/ui.jcef/ui.jcef_resources.jar:${RUNPATH}platform/platform-impl/ui/ui.jar:${RUNPATH}platform/buildData/buildData.jar:${RUNPATH}platform/buildData/buildData_resources.jar:${RUNPATH}platform/locking.impl/locking.impl.jar:${RUNPATH}../lib++_repo_rules+rwmutex-idea-0_0_8_http/file/rwmutex-idea-0.0.8.jar:${RUNPATH}platform/platform-impl/ide-impl_resources.jar:${RUNPATH}platform/object-serializer/object-serializer.jar:${RUNPATH}../lib++_repo_rules+ion-java-1_11_10_http/file/ion-java-1.11.10.jar:${RUNPATH}platform/object-serializer/objectSerializer-annotations.jar:${RUNPATH}../lib++_repo_rules+groovy-jsr223-3_0_19_http/file/groovy-jsr223-3.0.19.jar:${RUNPATH}../lib++_repo_rules+groovy-json-3_0_19_http/file/groovy-json-3.0.19.jar:${RUNPATH}../lib++_repo_rules+groovy-templates-3_0_19_http/file/groovy-templates-3.0.19.jar:${RUNPATH}../lib++_repo_rules+groovy-xml-3_0_19_http/file/groovy-xml-3.0.19.jar:${RUNPATH}../lib++_repo_rules+protobuf-java-3_24_4-jb_2_http/file/protobuf-java-3.24.4-jb.2.jar:${RUNPATH}../lib++_repo_rules+jgoodies-common-1_4_0_http/file/jgoodies-common-1.4.0.jar:${RUNPATH}../lib++_repo_rules+forms-1_1-preview_http/file/forms-1.1-preview.jar:${RUNPATH}../lib++_repo_rules+bcpkix-jdk18on-1_80_http/file/bcpkix-jdk18on-1.80.jar:${RUNPATH}../lib++_repo_rules+bcutil-jdk18on-1_80_http/file/bcutil-jdk18on-1.80.jar:${RUNPATH}../lib++_repo_rules+bcprov-jdk18on-1_80_http/file/bcprov-jdk18on-1.80.jar:${RUNPATH}platform/platform-resources/resources_resources.jar:${RUNPATH}platform/platform-resources-en/resources-en_resources.jar:${RUNPATH}platform/syntax/syntax-psi/psi.jar:${RUNPATH}platform/syntax/syntax-util/util.jar:${RUNPATH}platform/syntax/syntax-i18n/i18n.jar:${RUNPATH}platform/syntax/syntax-extensions/extensions.jar:${RUNPATH}platform/syntax/syntax-util/util_resources.jar:${RUNPATH}platform/syntax/syntax-psi/psi_resources.jar:${RUNPATH}platform/platform-impl/bootstrap/bootstrap.jar:${RUNPATH}platform/bootstrap/coroutine/coroutine.jar:${RUNPATH}platform/platform-impl/bootstrap/eel/eel.jar:${RUNPATH}platform/platform-impl/bootstrap/kernel/kernel.jar:${RUNPATH}../lib++_repo_rules+dd-plist-1_28_http/file/dd-plist-1.28.jar:${RUNPATH}platform/boot/boot.jar:${RUNPATH}platform/boot/boot_resources.jar:${RUNPATH}platform/remote-servers/clouds/clouds.jar:${RUNPATH}platform/remote-servers/api/remoteServers.jar:${RUNPATH}platform/remote-servers/agent-rt/remoteServers-agent-rt.jar:${RUNPATH}platform/remote-servers/api/remoteServers_resources.jar:${RUNPATH}platform/remote-servers/impl/impl.jar:${RUNPATH}platform/execution-impl/execution-impl.jar:${RUNPATH}platform/macro/macro.jar:${RUNPATH}../lib++_repo_rules+jediterm-core-3_54_http/file/jediterm-core-3.54.jar:${RUNPATH}../lib++_repo_rules+jediterm-ui-3_54_http/file/jediterm-ui-3.54.jar:${RUNPATH}platform/wsl-impl/wsl-impl.jar:${RUNPATH}../lib++_repo_rules+ktor-network-tls-jvm-3_0_3_http/file/ktor-network-tls-jvm-3.0.3.jar:${RUNPATH}../lib++_repo_rules+ktor-network-jvm-3_0_3_http/file/ktor-network-jvm-3.0.3.jar:${RUNPATH}platform/execution-impl/execution-impl_resources.jar:${RUNPATH}platform/xdebugger-api/debugger.jar:${RUNPATH}platform/xdebugger-api/debugger_resources.jar:${RUNPATH}platform/remote-servers/impl/impl_resources.jar:${RUNPATH}platform/remote-servers/impl/impl_resources_1.jar:${RUNPATH}platform/remote-servers/clouds/clouds_resources.jar:${RUNPATH}platform/execution.dashboard/execution.dashboard.jar:${RUNPATH}platform/lang-impl/lang-impl.jar:${RUNPATH}../lib++_repo_rules+velocity-engine-core-2_3_http/file/velocity-engine-core-2.3.jar:${RUNPATH}../lib++_repo_rules+cli-parser-1_1_6_http/file/cli-parser-1.1.6.jar:${RUNPATH}platform/usageView-impl/usageView-impl.jar:${RUNPATH}platform/structure-view-impl/structureView-impl.jar:${RUNPATH}platform/structure-view-impl/structureView-impl_resources.jar:${RUNPATH}../lib++_repo_rules+commons-logging-1_2_http/file/commons-logging-1.2.jar:${RUNPATH}platform/diff-impl/diff-impl.jar:${RUNPATH}platform/diff-impl/diff-impl_resources.jar:${RUNPATH}../lib++_repo_rules+groovy-3_0_19_http/file/groovy-3.0.19.jar:${RUNPATH}../lib++_repo_rules+xstream-1_4_21_http/file/xstream-1.4.21.jar:${RUNPATH}../lib++_repo_rules+mxparser-1_2_2_http/file/mxparser-1.2.2.jar:${RUNPATH}../lib++_repo_rules+xmlpull-1_1_3_1_http/file/xmlpull-1.1.3.1.jar:${RUNPATH}../lib++_repo_rules+xz-1_10_http/file/xz-1.10.jar:${RUNPATH}platform/tracing/tracing-rt.jar:${RUNPATH}platform/platform-impl/codeinsight-inline/ide-codeinsight-inline.jar:${RUNPATH}platform/feedback/feedback.jar:${RUNPATH}platform/platform-impl/internal/internal.jar:${RUNPATH}platform/platform-impl/internal/internal_resources.jar:${RUNPATH}platform/feedback/feedback_resources.jar:${RUNPATH}../lib++_repo_rules+kotlinx-html-jvm-0_12_0_http/file/kotlinx-html-jvm-0.12.0.jar:${RUNPATH}platform/configuration-store-impl/configurationStore-impl.jar:${RUNPATH}../lib++_repo_rules+snakeyaml-engine-2_9_http/file/snakeyaml-engine-2.9.jar:${RUNPATH}platform/configuration-store-impl/configurationStore-impl_resources.jar:${RUNPATH}platform/foldings/foldings.jar:${RUNPATH}platform/experiment/experiment.jar:${RUNPATH}platform/experiment/experiment_resources.jar:${RUNPATH}platform/lang-impl/lang-impl_resources.jar:${RUNPATH}platform/execution.serviceView/execution.serviceView.jar:${RUNPATH}platform/navbar/frontend/frontend.jar:${RUNPATH}platform/navbar/shared/navbar.jar:${RUNPATH}platform/navbar/shared/navbar_resources.jar:${RUNPATH}platform/navbar/frontend/frontend_resources.jar:${RUNPATH}platform/execution.serviceView/execution.serviceView_resources.jar:${RUNPATH}platform/execution.dashboard/execution.dashboard_resources.jar:${RUNPATH}platform/kernel/intellij.platform.kernel.impl/impl.jar:${RUNPATH}platform/kernel/intellij.platform.kernel.impl/impl_resources.jar:${RUNPATH}platform/platform-impl/ui-inspector/ide-ui-inspector.jar:${RUNPATH}platform/platform-impl/ui-inspector/ide-ui-inspector_resources.jar:${RUNPATH}platform/inline-completion/shared/inline-completion.jar:${RUNPATH}platform/inline-completion/shared/inline-completion_resources.jar:${RUNPATH}platform/bookmarks/bookmarks.jar:${RUNPATH}platform/favoritesTreeView/favoritesTreeView.jar:${RUNPATH}platform/bookmarks/bookmarks_resources.jar:${RUNPATH}platform/todo/todo.jar:${RUNPATH}platform/todo/todo_resources.jar:${RUNPATH}platform/find/find.jar:${RUNPATH}platform/find/find_resources.jar:${RUNPATH}platform/settings-local/settings-local.jar:${RUNPATH}../lib++_repo_rules+jackson-dataformat-cbor-2_19_0_http/file/jackson-dataformat-cbor-2.19.0.jar:${RUNPATH}../lib++_repo_rules+kotlinx-serialization-cbor-jvm-1_8_1_http/file/kotlinx-serialization-cbor-jvm-1.8.1.jar:${RUNPATH}platform/settings-local/settings-local_resources.jar:${RUNPATH}platform/xdebugger-impl/shared/shared.jar:${RUNPATH}platform/xdebugger-impl/shared/shared_resources.jar:${RUNPATH}platform/xdebugger-impl/rpc/rpc.jar:${RUNPATH}platform/xdebugger-impl/rpc/rpc_resources.jar:${RUNPATH}platform/xdebugger-impl/frontend/frontend.jar:${RUNPATH}platform/xdebugger-impl/debugger-impl.jar:${RUNPATH}platform/xdebugger-impl/debugger-impl_resources.jar:${RUNPATH}platform/platform-frontend/frontend.jar:${RUNPATH}platform/platform-frontend/frontend_resources.jar:${RUNPATH}platform/execution-impl/frontend/frontend.jar:${RUNPATH}platform/execution-impl/frontend/frontend_resources.jar:${RUNPATH}platform/xdebugger-impl/frontend/frontend_resources.jar:${RUNPATH}platform/searchEverywhere/frontend/frontend.jar:${RUNPATH}platform/searchEverywhere/shared/searchEverywhere.jar:${RUNPATH}platform/searchEverywhere/shared/searchEverywhere_resources.jar:${RUNPATH}platform/searchEverywhere/frontend/frontend_resources.jar:${RUNPATH}platform/vcs-impl/frontend/frontend.jar:${RUNPATH}platform/vcs-impl/shared/shared.jar:${RUNPATH}platform/vcs-impl/shared/shared_resources.jar:${RUNPATH}platform/recentFiles/frontend/frontend.jar:${RUNPATH}platform/recentFiles/shared/recentFiles.jar:${RUNPATH}platform/recentFiles/shared/recentFiles_resources.jar:${RUNPATH}platform/recentFiles/frontend/frontend_resources.jar:${RUNPATH}platform/vcs-impl/frontend/frontend_resources.jar:${RUNPATH}platform/bookmarks/frontend/frontend.jar:${RUNPATH}platform/bookmarks/frontend/frontend_resources.jar:${RUNPATH}platform/pluginManager/frontend/frontend.jar:${RUNPATH}platform/pluginManager/shared/shared.jar:${RUNPATH}platform/pluginManager/shared/shared_resources.jar:${RUNPATH}platform/pluginManager/frontend/frontend_resources.jar:${RUNPATH}platform/execution.dashboard/frontend/frontend_resources.jar:${RUNPATH}platform/execution.serviceView/frontend/frontend_resources.jar:${RUNPATH}platform/kernel/backend/backend.jar:${RUNPATH}platform/kernel/rpc.backend/rpc.backend.jar:${RUNPATH}fleet/rpc.server/rpc.server.jar:${RUNPATH}platform/kernel/rpc.backend/rpc.backend_resources.jar:${RUNPATH}platform/kernel/backend/backend_resources.jar:${RUNPATH}platform/backend/backend_resources.jar:${RUNPATH}platform/navbar/backend/backend.jar:${RUNPATH}platform/navbar/backend/backend_resources.jar:${RUNPATH}platform/project/backend/backend.jar:${RUNPATH}platform/project/backend/backend_resources.jar:${RUNPATH}platform/progress/backend/backend.jar:${RUNPATH}platform/progress/backend/backend_resources.jar:${RUNPATH}platform/xdebugger-impl/backend/backend.jar:${RUNPATH}platform/execution-impl/backend/backend.jar:${RUNPATH}platform/execution-impl/backend/backend_resources.jar:${RUNPATH}platform/xdebugger-impl/backend/backend_resources.jar:${RUNPATH}platform/searchEverywhere/backend/backend.jar:${RUNPATH}platform/searchEverywhere/backend/backend_resources.jar:${RUNPATH}platform/vcs-impl/backend/backend.jar:${RUNPATH}platform/vcs-api/vcs.jar:${RUNPATH}platform/vcs-api/vcs-api-core/vcs-core.jar:${RUNPATH}platform/vcs-api/vcs-api-core/vcs-core_resources.jar:${RUNPATH}platform/vcs-impl/vcs-impl.jar:${RUNPATH}platform/vcs-log/api/vcs-log.jar:${RUNPATH}platform/vcs-log/graph-api/vcs-log-graph.jar:${RUNPATH}platform/built-in-server/builtInServer-impl.jar:${RUNPATH}../lib++_repo_rules+netty-codec-compression-4_2_0_RC2_http/file/netty-codec-compression-4.2.0.RC2.jar:${RUNPATH}platform/built-in-server/builtInServer-impl_resources.jar:${RUNPATH}libraries/microba/microba.jar:${RUNPATH}libraries/microba/microba_resources.jar:${RUNPATH}platform/vcs-impl/vcs-impl_resources.jar:${RUNPATH}platform/vcs-impl/backend/backend_resources.jar:${RUNPATH}platform/bookmarks/backend/backend.jar:${RUNPATH}platform/bookmarks/backend/backend_resources.jar:${RUNPATH}platform/recentFiles/backend/backend.jar:${RUNPATH}platform/recentFiles/backend/backend_resources.jar:${RUNPATH}platform/editor/backend/backend.jar:${RUNPATH}platform/editor/shared/editor.jar:${RUNPATH}platform/editor/shared/editor_resources.jar:${RUNPATH}platform/editor/backend/backend_resources.jar:${RUNPATH}platform/execution.dashboard/backend/backend_resources.jar:${RUNPATH}platform/identifiers/backend/backend.jar:${RUNPATH}platform/identifiers/shared/shared.jar:${RUNPATH}platform/identifiers/shared/shared_resources.jar:${RUNPATH}platform/identifiers/backend/backend_resources.jar:${RUNPATH}spellchecker/xml/xml.jar:${RUNPATH}spellchecker/spellchecker.jar:${RUNPATH}xml/openapi/xml.jar:${RUNPATH}xml/xml-analysis-api/analysis.jar:${RUNPATH}xml/xml-psi-api/psi.jar:${RUNPATH}xml/xml-parser/parser.jar:${RUNPATH}xml/xml-parser/parser_resources.jar:${RUNPATH}xml/xml-psi-api/psi_resources.jar:${RUNPATH}xml/xml-analysis-api/analysis_resources.jar:${RUNPATH}xml/xml-structure-view-api/structureView.jar:${RUNPATH}xml/xml-structure-view-api/structureView_resources.jar:${RUNPATH}xml/openapi/xml_resources.jar:${RUNPATH}xml/dom-openapi/dom.jar:${RUNPATH}xml/dom-openapi/dom_resources.jar:${RUNPATH}../lib++_repo_rules+gec-spell-engine-local-jvm-0_4_71_http/file/gec-spell-engine-local-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+utils-common-jvm-0_4_71_http/file/utils-common-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+model-gec-jvm-0_4_71_http/file/model-gec-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+model-text-jvm-0_4_71_http/file/model-text-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+model-common-jvm-0_4_71_http/file/model-common-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+nlp-langs-jvm-0_4_71_http/file/nlp-langs-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+nlp-common-jvm-0_4_71_http/file/nlp-common-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+nlp-patterns-jvm-0_4_71_http/file/nlp-patterns-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+nlp-similarity-jvm-0_4_71_http/file/nlp-similarity-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+nlp-phonetics-jvm-0_4_71_http/file/nlp-phonetics-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+nlp-tokenizer-jvm-0_4_71_http/file/nlp-tokenizer-jvm-0.4.71.jar:${RUNPATH}../lib++_repo_rules+hunspell-en-jvm-0_2_274_http/file/hunspell-en-jvm-0.2.274.jar:${RUNPATH}../lib++_repo_rules+nlp-detect-jvm-0_4_71_http/file/nlp-detect-jvm-0.4.71.jar:${RUNPATH}libraries/ai.grazie.spell.gec.engine.local/ai.grazie.spell.gec.engine.local_resources.jar:${RUNPATH}../lib++_repo_rules+utils-lucene-lt-compatibility-0_4_71_http/file/utils-lucene-lt-compatibility-0.4.71.jar:${RUNPATH}../lib++_repo_rules+java-string-similarity-2_0_0_http/file/java-string-similarity-2.0.0.jar:${RUNPATH}../lib++_repo_rules+lucene-analysis-common-9_12_0_http/file/lucene-analysis-common-9.12.0.jar:${RUNPATH}../lib++_repo_rules+lucene-core-9_12_0_http/file/lucene-core-9.12.0.jar:${RUNPATH}libraries/lucene.common/lucene.common_resources.jar:${RUNPATH}spellchecker/spellchecker_resources.jar:${RUNPATH}spellchecker/spellchecker_resources_1.jar:${RUNPATH}xml/impl/impl.jar:${RUNPATH}xml/xml-psi-impl/psi-impl.jar:${RUNPATH}xml/xml-frontback-impl/frontback-impl.jar:${RUNPATH}xml/xml-frontback-impl/frontback-impl_resources.jar:${RUNPATH}../lib++_repo_rules+xercesImpl-2_12_2_http/file/xercesImpl-2.12.2.jar:${RUNPATH}RegExpSupport/regexp.jar:${RUNPATH}RegExpSupport/regexp_resources.jar:${RUNPATH}../lib++_repo_rules+xml-resolver-1_2_http/file/xml-resolver-1.2.jar:${RUNPATH}platform/markdown-utils/markdown-utils.jar:${RUNPATH}../lib++_repo_rules+markdown-jvm-0_7_2_http/file/markdown-jvm-0.7.2.jar:${RUNPATH}platform/polySymbols/polySymbols.jar:${RUNPATH}platform/polySymbols/polySymbols_resources.jar:${RUNPATH}platform/polySymbols/backend/backend.jar:${RUNPATH}platform/polySymbols/backend/backend_resources.jar:${RUNPATH}xml/xml-psi-impl/psi-impl_resources.jar:${RUNPATH}xml/xml-psi-impl/psi-impl_resources_1.jar:${RUNPATH}xml/xml-analysis-impl/analysis-impl.jar:${RUNPATH}xml/xml-analysis-impl/analysis-impl_resources.jar:${RUNPATH}xml/xml-structure-view-impl/structureView-impl.jar:${RUNPATH}xml/xml-structure-view-impl/structureView-impl_resources.jar:${RUNPATH}xml/impl/impl_resources.jar:${RUNPATH}spellchecker/xml/xml_resources.jar:${RUNPATH}platform/find/backend/backend.jar:${RUNPATH}platform/find/backend/backend_resources.jar:${RUNPATH}platform/monolith/monolith_resources.jar:${RUNPATH}platform/navbar/monolith/monolith.jar:${RUNPATH}platform/navbar/monolith/monolith_resources.jar:${RUNPATH}platform/lvcs-impl/lvcs-impl.jar:${RUNPATH}platform/lvcs-impl/lvcs-impl_resources.jar:${RUNPATH}platform/starter/starter.jar:${RUNPATH}platform/testRunner/testRunner.jar:${RUNPATH}platform/testRunner/testRunner_resources.jar:${RUNPATH}platform/vcs-impl/exec/exec.jar:${RUNPATH}platform/vcs-impl/exec/exec_resources.jar:${RUNPATH}platform/vcs-impl/lang/lang.jar:${RUNPATH}platform/vcs-impl/lang/lang_resources.jar:${RUNPATH}platform/vcs-impl/lang/actions/actions_resources.jar:${RUNPATH}community-resources/customization_resources.jar:${RUNPATH}java/ide-resources/ide-resources_resources.jar:${RUNPATH}../lib++_repo_rules+tips-intellij-idea-community-241_62_http/file/tips-intellij-idea-community-241.62.jar:${RUNPATH}idea/customization/base/base.jar:${RUNPATH}idea/customization/base/base_resources.jar:${RUNPATH}plugins/copyright/copyright.jar:${RUNPATH}platform/external-system-api/externalSystem.jar:${RUNPATH}platform/external-system-rt/externalSystem-rt.jar:${RUNPATH}platform/external-system-api/dependency-updater/dependency-updater.jar:${RUNPATH}platform/external-system-api/dependency-updater/dependency-updater_resources.jar:${RUNPATH}platform/external-system-api/externalSystem_resources.jar:${RUNPATH}plugins/copyright/copyright_resources.jar:${RUNPATH}plugins/git4idea/vcs-git.jar:${RUNPATH}platform/dvcs-api/vcs-dvcs.jar:${RUNPATH}platform/dvcs-impl/shared/shared.jar:${RUNPATH}platform/dvcs-impl/shared/shared_resources.jar:${RUNPATH}platform/dvcs-api/vcs-dvcs_resources.jar:${RUNPATH}../lib++_repo_rules+cucumber-jvm-deps-1_0_5_http/file/cucumber-jvm-deps-1.0.5.jar:${RUNPATH}plugins/git4idea/rt/rt.jar:${RUNPATH}platform/external-process-auth-helper/rt/rt.jar:${RUNPATH}platform/dvcs-impl/vcs-dvcs-impl.jar:${RUNPATH}platform/vcs-log/impl/impl.jar:${RUNPATH}platform/vcs-log/graph/vcs-log-graph-impl.jar:${RUNPATH}../lib++_repo_rules+kotlinx-coroutines-guava-1_10_1-intellij-4_http/file/kotlinx-coroutines-guava-1.10.1-intellij-4.jar:${RUNPATH}platform/sqlite/sqlite.jar:${RUNPATH}../lib++_repo_rules+native-3_42_0-jb_1_http/file/native-3.42.0-jb.1.jar:${RUNPATH}platform/vcs-log/impl/impl_resources.jar:${RUNPATH}platform/dvcs-impl/vcs-dvcs-impl_resources.jar:${RUNPATH}../lib++_repo_rules+ini4j-0_5_5-2_http/file/ini4j-0.5.5-2.jar:${RUNPATH}platform/external-process-auth-helper/external-process-auth-helper.jar:${RUNPATH}platform/external-process-auth-helper/external-process-auth-helper_resources.jar:${RUNPATH}platform/collaboration-tools/collaboration-tools.jar:${RUNPATH}platform/credential-store-ui/credentialStore-ui.jar:${RUNPATH}platform/credential-store-impl/credentialStore-impl.jar:${RUNPATH}../lib++_repo_rules+snakeyaml-2_4_http/file/snakeyaml-2.4.jar:${RUNPATH}../lib++_repo_rules+dbus-java-transport-native-unixsocket-4_2_1_http/file/dbus-java-transport-native-unixsocket-4.2.1.jar:${RUNPATH}../lib++_repo_rules+dbus-java-core-4_2_1_http/file/dbus-java-core-4.2.1.jar:${RUNPATH}platform/credential-store-impl/credentialStore-impl_resources.jar:${RUNPATH}platform/collaboration-tools/auth-base/collaborationTools-auth-base.jar:${RUNPATH}platform/collaboration-tools/auth/auth.jar:${RUNPATH}platform/collaboration-tools/collaboration-tools_resources.jar:${RUNPATH}plugins/performanceTesting/core/performanceTesting.jar:${RUNPATH}platform/remote-driver/model/model.jar:${RUNPATH}platform/remote-driver/model/model_resources.jar:${RUNPATH}../lib++_repo_rules+oshi-core-6_6_0_http/file/oshi-core-6.6.0.jar:${RUNPATH}platform/remote-driver/core/driver-impl.jar:${RUNPATH}platform/remote-driver/core/driver-impl_resources.jar:${RUNPATH}platform/remote-driver/client/client.jar:${RUNPATH}platform/remote-driver/client/client_resources.jar:${RUNPATH}plugins/performanceTesting/event-bus/tools-ide-starter-bus.jar:${RUNPATH}plugins/performanceTesting/event-bus/tools-ide-starter-bus_resources.jar:${RUNPATH}plugins/performanceTesting/core/performanceTesting_resources.jar:${RUNPATH}platform/new-ui-onboarding/new-ui-onboarding.jar:${RUNPATH}platform/new-ui-onboarding/new-ui-onboarding_resources.jar:${RUNPATH}plugins/terminal/terminal.jar:${RUNPATH}plugins/terminal/completion/completion.jar:${RUNPATH}../lib++_repo_rules+completion-spec-0_4_0_http/file/completion-spec-0.4.0.jar:${RUNPATH}../lib++_repo_rules+completion-db-with-extensions-0_5_0_http/file/completion-db-with-extensions-0.5.0.jar:${RUNPATH}../lib++_repo_rules+completion-ranking-sh-0_0_2_http/file/completion-ranking-sh-0.0.2.jar:${RUNPATH}plugins/terminal/terminal_resources.jar:${RUNPATH}plugins/git4idea/shared/shared.jar:${RUNPATH}plugins/git4idea/shared/shared_resources.jar:${RUNPATH}plugins/git4idea/vcs-git_resources.jar:${RUNPATH}plugins/git4idea/vcs-git_resources_1.jar:${RUNPATH}plugins/git4idea/frontend/frontend.jar:${RUNPATH}plugins/git4idea/frontend/frontend_resources.jar:${RUNPATH}plugins/git-features-trainer/vcs-git-featuresTrainer.jar:${RUNPATH}../lib++_repo_rules+git-learning-project-212_0_2_http/file/git-learning-project-212.0.2.jar:${RUNPATH}plugins/ide-features-trainer/featuresTrainer.jar:${RUNPATH}../lib++_repo_rules+assertj-core-3_27_3_http/file/assertj-core-3.27.3.jar:${RUNPATH}../lib++_repo_rules+byte-buddy-1_15_11_http/file/byte-buddy-1.15.11.jar:${RUNPATH}../lib++_repo_rules+assertj-swing-3_17_1_http/file/assertj-swing-3.17.1.jar:${RUNPATH}platform/tips-of-the-day/tips.jar:${RUNPATH}platform/tips-of-the-day/tips_resources.jar:${RUNPATH}plugins/ide-features-trainer/featuresTrainer_resources.jar:${RUNPATH}plugins/git-features-trainer/vcs-git-featuresTrainer_resources.jar:${RUNPATH}images/images.jar:${RUNPATH}images/images_resources.jar:${RUNPATH}plugins/svn4idea/vcs-svn.jar:${RUNPATH}../lib++_repo_rules+jaxb-api-2_3_1_http/file/jaxb-api-2.3.1.jar:${RUNPATH}../lib++_repo_rules+javax_activation-1_2_0_http/file/javax.activation-1.2.0.jar:${RUNPATH}plugins/svn4idea/vcs-svn_resources.jar:${RUNPATH}../lib++_repo_rules+jaxb-runtime-2_3_9_http/file/jaxb-runtime-2.3.9.jar:${RUNPATH}../lib++_repo_rules+txw2-2_3_9_http/file/txw2-2.3.9.jar:${RUNPATH}../lib++_repo_rules+istack-commons-runtime-3_0_12_http/file/istack-commons-runtime-3.0.12.jar:${RUNPATH}../lib++_repo_rules+jakarta_activation-1_2_2_http/file/jakarta.activation-1.2.2.jar:${RUNPATH}../lib++_repo_rules+sqlite-jdbc-3_49_1_0_http/file/sqlite-jdbc-3.49.1.0.jar:${RUNPATH}plugins/github/github-core/vcs-github.jar:${RUNPATH}plugins/github/github-core/vcs-github_resources.jar:${RUNPATH}plugins/github/github-core/vcs-github_resources_1.jar:${RUNPATH}plugins/hg4idea/vcs-hg.jar:${RUNPATH}plugins/hg4idea/vcs-hg_resources.jar:${RUNPATH}plugins/terminal/frontend/frontend.jar:${RUNPATH}plugins/terminal/frontend/frontend_resources.jar:${RUNPATH}plugins/terminal/backend/backend.jar:${RUNPATH}plugins/terminal/backend/backend_resources.jar:${RUNPATH}plugins/stats-collector/stats-collector.jar:${RUNPATH}plugins/completion-ml-ranking/completion-ml-ranking.jar:${RUNPATH}platform/ml-impl/ml-impl.jar:${RUNPATH}../lib++_repo_rules+ngram-slp-0_0_3_http/file/ngram-slp-0.0.3.jar:${RUNPATH}../lib++_repo_rules+catboost-shadow-need-slf4j-1_2_5_http/file/catboost-shadow-need-slf4j-1.2.5.jar:${RUNPATH}../lib++_repo_rules+ml-tools-86_http/file/ml-tools-86.jar:${RUNPATH}../lib++_repo_rules+ml-tools-suspendable-76_http/file/ml-tools-suspendable-76.jar:${RUNPATH}platform/ml-impl/ml-impl_resources.jar:${RUNPATH}plugins/completion-ml-ranking/completion-ml-ranking_resources.jar:${RUNPATH}../lib++_repo_rules+completion-log-events-0_0_3_http/file/completion-log-events-0.0.3.jar:${RUNPATH}plugins/stats-collector/stats-collector_resources.jar:${RUNPATH}plugins/editorconfig/editorconfig-plugin_resources.jar:${RUNPATH}plugins/editorconfig/common/common.jar:${RUNPATH}plugins/editorconfig/common/common_resources.jar:${RUNPATH}plugins/editorconfig/frontend/frontend.jar:${RUNPATH}plugins/editorconfig/frontend/frontend_resources.jar:${RUNPATH}plugins/editorconfig/backend/backend.jar:${RUNPATH}../lib++_repo_rules+ec4j-core-0_3_0_http/file/ec4j-core-0.3.0.jar:${RUNPATH}plugins/editorconfig/backend/backend_resources.jar:${RUNPATH}plugins/editorconfig/backend/backend_resources_1.jar:${RUNPATH}plugins/changeReminder/changeReminder.jar:${RUNPATH}../lib++_repo_rules+randomForestRegressor-0_0_11_http/file/randomForestRegressor-0.0.11.jar:${RUNPATH}plugins/changeReminder/changeReminder_resources.jar:${RUNPATH}plugins/sh/sh_resources.jar:${RUNPATH}plugins/sh/core/core.jar:${RUNPATH}plugins/sh/core/core_resources.jar:${RUNPATH}plugins/sh/terminal/terminal.jar:${RUNPATH}plugins/sh/terminal/terminal_resources.jar:${RUNPATH}plugins/sh/copyright/copyright.jar:${RUNPATH}plugins/sh/copyright/copyright_resources.jar:${RUNPATH}plugins/sh/markdown/markdown.jar:${RUNPATH}plugins/markdown/core/markdown.jar:${RUNPATH}plugins/markdown/core/markdown_resources.jar:${RUNPATH}plugins/sh/markdown/markdown_resources.jar:${RUNPATH}plugins/sh/python/python.jar:${RUNPATH}python/python-psi-api/psi.jar:${RUNPATH}python/python-parser/parser.jar:${RUNPATH}python/python-parser/parser_resources.jar:${RUNPATH}python/python-ast/ast.jar:${RUNPATH}python/python-ast/ast_resources.jar:${RUNPATH}python/python-syntax-core/syntax-core.jar:${RUNPATH}python/python-syntax-core/syntax-core_resources.jar:${RUNPATH}python/python-psi-api/psi_resources.jar:${RUNPATH}plugins/sh/python/python_resources.jar:${RUNPATH}plugins/terminal/sh/sh.jar:${RUNPATH}plugins/terminal/sh/sh_resources.jar:${RUNPATH}platform/settings-sync-core/settingsSync-core.jar:${RUNPATH}../lib++_repo_rules+org_eclipse_jgit-6_6_1_202309021850-r-jb-202407181518_http/file/org.eclipse.jgit-6.6.1.202309021850-r-jb-202407181518.jar:${RUNPATH}../lib++_repo_rules+JavaEWAH-1_2_3_http/file/JavaEWAH-1.2.3.jar:${RUNPATH}platform/settings-sync-core/settingsSync-core_resources.jar:${RUNPATH}plugins/settings-sync/jba/settingsSync.jar:${RUNPATH}../lib++_repo_rules+cloudconfig-2023_9_http/file/cloudconfig-2023.9.jar:${RUNPATH}plugins/settings-sync/jba/settingsSync_resources.jar:${RUNPATH}plugins/laf/macos/macos.jar:${RUNPATH}plugins/laf/macos/macos_resources.jar:${RUNPATH}plugins/laf/win10/win10.jar:${RUNPATH}plugins/laf/win10/win10_resources.jar:${RUNPATH}plugins/keymaps/eclipse-keymap/keymap-eclipse_resources.jar:${RUNPATH}plugins/keymaps/visual-studio-keymap/keymap-visualStudio_resources.jar:${RUNPATH}plugins/keymaps/netbeans5.6-keymap/keymap-netbeans_resources.jar:${RUNPATH}platform/warmup/warmup.jar:${RUNPATH}platform/warmup/warmup_resources.jar:${RUNPATH}platform/smart-update/smart-update.jar:${RUNPATH}platform/smart-update/smart-update_resources.jar:${RUNPATH}platform/new-users-onboarding/new-users-onboarding.jar:${RUNPATH}platform/new-users-onboarding/new-users-onboarding_resources.jar:${RUNPATH}plugins/github/community/community_resources.jar:${RUNPATH}plugins/gitlab/gitlab-community/vcs-gitlab-community.jar:${RUNPATH}plugins/gitlab/gitlab-community/vcs-gitlab-community_resources.jar:${RUNPATH}plugins/gitlab/gitlab-yaml/vcs-gitlab-yaml.jar:${RUNPATH}plugins/gitlab/gitlab-core/vcs-gitlab.jar:${RUNPATH}plugins/gitlab/gitlab-core/vcs-gitlab_resources.jar:${RUNPATH}plugins/gitlab/gitlab-core/vcs-gitlab_resources_1.jar:${RUNPATH}plugins/yaml/backend/backend.jar:${RUNPATH}json/backend/backend.jar:${RUNPATH}json/json.jar:${RUNPATH}json/json_resources.jar:${RUNPATH}../lib++_repo_rules+jackson-dataformat-yaml-2_19_0_http/file/jackson-dataformat-yaml-2.19.0.jar:${RUNPATH}json/backend/backend_resources.jar:${RUNPATH}plugins/yaml/yaml.jar:${RUNPATH}plugins/yaml/yaml_resources.jar:${RUNPATH}plugins/yaml/backend/backend_resources.jar:${RUNPATH}plugins/gitlab/gitlab-yaml/vcs-gitlab-yaml_resources.jar:${RUNPATH}plugins/github/github-json/vcs-github-json.jar:${RUNPATH}plugins/github/github-json/vcs-github-json_resources.jar:${RUNPATH}plugins/git-modal-commit/vcs-git-commit-modal.jar:${RUNPATH}plugins/git-modal-commit/vcs-git-commit-modal_resources.jar"
fi

# Export the locations which will be used to find the location of the classes from the classpath file.
export SELF_LOCATION="$self"
export CLASSLOADER_PREFIX_PATH="${RUNPATH}"

# If using Jacoco in offline instrumentation mode, the CLASSPATH contains instrumented files.
# We need to make the metadata jar with uninstrumented classes available for generating
# the lcov-compatible coverage report, and we don't want it on the classpath.



# export JACOCO_IS_JAR_WRAPPED for compatibility with older versions of
# JacocoCoverageRunner that check for this and not CLASSPATH_JAR
export JACOCO_IS_JAR_WRAPPED=0
export CLASSPATH_JAR=""

if [[ -n "$JVM_DEBUG_PORT" ]]; then
  JVM_DEBUG_SUSPEND=${DEFAULT_JVM_DEBUG_SUSPEND:-"y"}
  JVM_DEBUG_FLAGS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=${JVM_DEBUG_SUSPEND},address=${JVM_DEBUG_PORT}"
fi

if [[ -n "$MAIN_ADVICE_CLASSPATH" ]]; then
  CLASSPATH="${MAIN_ADVICE_CLASSPATH}:${CLASSPATH}"
fi

# Check if TEST_TMPDIR is available to use for scratch.
if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
  JVM_FLAGS+=" -Djava.io.tmpdir=$TEST_TMPDIR"
fi

ARGS=(
  ${JVM_DEBUG_FLAGS}
  ${JVM_FLAGS}
  --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.ref=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.nio.charset=ALL-UNNAMED --add-opens=java.base/java.text=ALL-UNNAMED --add-opens=java.base/java.time=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED --add-opens=java.base/jdk.internal.vm=ALL-UNNAMED --add-opens=java.base/sun.net.dns=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/sun.nio.fs=ALL-UNNAMED --add-opens=java.base/sun.security.ssl=ALL-UNNAMED --add-opens=java.base/sun.security.util=ALL-UNNAMED --add-opens=java.desktop/com.apple.eawt=ALL-UNNAMED --add-opens=java.desktop/com.apple.eawt.event=ALL-UNNAMED --add-opens=java.desktop/com.apple.laf=ALL-UNNAMED --add-opens=java.desktop/com.sun.java.swing=ALL-UNNAMED --add-opens=java.desktop/com.sun.java.swing.plaf.gtk=ALL-UNNAMED --add-opens=java.desktop/java.awt=ALL-UNNAMED --add-opens=java.desktop/java.awt.dnd.peer=ALL-UNNAMED --add-opens=java.desktop/java.awt.event=ALL-UNNAMED --add-opens=java.desktop/java.awt.font=ALL-UNNAMED --add-opens=java.desktop/java.awt.image=ALL-UNNAMED --add-opens=java.desktop/java.awt.peer=ALL-UNNAMED --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.desktop/javax.swing.plaf.basic=ALL-UNNAMED --add-opens=java.desktop/javax.swing.text=ALL-UNNAMED --add-opens=java.desktop/javax.swing.text.html=ALL-UNNAMED --add-opens=java.desktop/javax.swing.text.html.parser=ALL-UNNAMED --add-opens=java.desktop/sun.awt=ALL-UNNAMED --add-opens=java.desktop/sun.awt.X11=ALL-UNNAMED --add-opens=java.desktop/sun.awt.datatransfer=ALL-UNNAMED --add-opens=java.desktop/sun.awt.image=ALL-UNNAMED --add-opens=java.desktop/sun.awt.windows=ALL-UNNAMED --add-opens=java.desktop/sun.font=ALL-UNNAMED --add-opens=java.desktop/sun.java2d=ALL-UNNAMED --add-opens=java.desktop/sun.lwawt=ALL-UNNAMED --add-opens=java.desktop/sun.lwawt.macosx=ALL-UNNAMED --add-opens=java.desktop/sun.swing=ALL-UNNAMED --add-opens=java.management/sun.management=ALL-UNNAMED --add-opens=jdk.attach/sun.tools.attach=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-opens=jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED --add-opens=jdk.jdi/com.sun.tools.jdi=ALL-UNNAMED
  "${JVM_FLAGS_CMDLINE[@]}"
  ${MAIN_ADVICE}
  com.intellij.idea.Main
  "${ARGS[@]}")


# Creates a JAR containing the classpath and put the result to stdout
function create_classpath_jar() {
  # Build class path.
  MANIFEST_CLASSPATH=()
  if is_windows; then
    CLASSPATH_SEPARATOR=";"
  else
    CLASSPATH_SEPARATOR=":"
  fi

  OLDIFS="$IFS"
  IFS="${CLASSPATH_SEPARATOR}" # Use a custom separator for the loop.
  current_dir=$(pwd)
  for path in ${CLASSPATH}; do
    # Loop through the characters of the path and convert characters that are
    # not alphanumeric nor -_.~/ to their 2-digit hexadecimal representation
    if [[ ! $path =~ ^[-_.~/a-zA-Z0-9]*$ ]]; then
      local i c buff
      local converted_path=""

      for ((i=0; i<${#path}; i++)); do
        c=${path:$i:1}
        case ${c} in
              [-_.~/a-zA-Z0-9] ) buff=${c} ;;
              * )               printf -v buff '%%%02x' "'$c'"
        esac
        converted_path+="${buff}"
      done
      path=${converted_path}
    fi

    if is_windows; then
      path="file:/${path}" # e.g. "file:/C:/temp/foo.jar"
    else
      # If not absolute, qualify the path
      case "${path}" in
        /*) ;; # Already an absolute path
        *) path="${current_dir}/${path}";; # Now qualified
      esac
      path="file:${path}" # e.g. "file:/usr/local/foo.jar"
    fi

    MANIFEST_CLASSPATH+=("${path}")
  done
  IFS="$OLDIFS"

  # Create manifest file
  MANIFEST_FILE="$(mktemp -t XXXXXXXX.jar_manifest)"
  (
    echo "Manifest-Version: 1.0"

    CLASSPATH_LINE="Class-Path: ${MANIFEST_CLASSPATH[*]}"
    CLASSPATH_MANIFEST_LINES=$(sed -E $'s/(.{71})/\\1\\\n /g' <<< "${CLASSPATH_LINE}")

    echo "$CLASSPATH_MANIFEST_LINES"
    echo "Created-By: Bazel"
  ) >$MANIFEST_FILE

  # Create classpath JAR file
  MANIFEST_JAR_FILE="$(mktemp -t XXXXXXXX-classpath.jar)"
  if is_windows; then
    MANIFEST_JAR_FILE="$(cygpath --windows "$MANIFEST_JAR_FILE")"
    MANIFEST_FILE="$(cygpath --windows "$MANIFEST_FILE")"
  fi
  if is_windows; then
    JARBIN="${JARBIN:=${JAVABIN%/java.exe}/jar.exe}"
  else
    JARBIN="${JARBIN:=${JAVABIN%/java}/jar}"
  fi
  $JARBIN cvfm "$MANIFEST_JAR_FILE" "$MANIFEST_FILE" >/dev/null || \
    die "ERROR: $self failed because $JARBIN failed"
  rm -f "$MANIFEST_FILE"

  echo "$MANIFEST_JAR_FILE"
}

# If the user didn't specify a --classpath_limit, use the default value.
if [ -z "$CLASSPATH_LIMIT" ]; then
  # Windows per-arg limit MAX_ARG_STRLEN == 8k
  # Linux per-arg limit MAX_ARG_STRLEN == 128k
  is_windows && CLASSPATH_LIMIT=7000 || CLASSPATH_LIMIT=120000
fi

# On non-macOS Unix, without any locale variable set, the JVM would use
# using ASCII rather than UTF-8 as the encoding for file system paths.
if ! is_macos; then
  if [ -z ${LC_CTYPE+x} ] && [ -z ${LC_ALL+x} ] && [ -z ${LANG+x} ]; then
    UTF8_LOCALE=$(available_utf8_locale)
    if [[ -n "$UTF8_LOCALE" ]]; then
      export LC_CTYPE="$UTF8_LOCALE"
    fi
  fi
fi

if (("${#CLASSPATH}" > ${CLASSPATH_LIMIT})); then
  # never need it anymore.
  export JACOCO_IS_JAR_WRAPPED=1
  CLASSPATH_MANIFEST_JAR=$(create_classpath_jar)
  export CLASSPATH_JAR="$(basename $CLASSPATH_MANIFEST_JAR)"
  "$JAVABIN" -classpath "$CLASSPATH_MANIFEST_JAR" "${ARGS[@]}"
  exit_code=$?
  rm -f "$CLASSPATH_MANIFEST_JAR"
  exit $exit_code
else
  export JACOCO_IS_JAR_WRAPPED=0
  export CLASSPATH_JAR=""
  exec "$JAVABIN" -classpath $CLASSPATH "${ARGS[@]}"
fi
