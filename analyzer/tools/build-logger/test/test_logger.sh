#!/bin/bash

#--- Initialize environment ---#

logger_dir=$1

export LD_PRELOAD=ldlogger.so
export LD_LIBRARY_PATH=$logger_dir/lib:$LD_LIBRARY_PATH
export CC_LOGGER_GCC_LIKE="gcc:g++:clang:clang++:cc:c++"
export CC_LOGGER_FILE=/tmp/logger_test_compilation_database.json
export CC_LOGGER_DEBUG_FILE=/tmp/logger_test_debug.log

source_file_name=logger_test_source.cpp
source_file=/tmp/$source_file_name
response_file=/tmp/logger_test_source.cpp.rsp
reference_file=/tmp/logger_test_reference.json

function assert_json {
  cat > $reference_file << EOF
[
	{
		"directory": "$(pwd)",
		"command": "$(which $2) $1",
		"file": "$3"
	}
]
EOF

  sed -i -e '$a\' $CC_LOGGER_FILE

  diff $reference_file $CC_LOGGER_FILE
  test -s $CC_LOGGER_DEBUG_FILE
}

#--- Test functions ---#

function test_compiler_path1 {
  IFS=':' read -ra my_array <<< $PATH
  compiler=$(find ${my_array[@]} -name g++-* -print -quit)

  if [ -n $compiler ]; then
    CC_LOGGER_GCC_LIKE="g++-" bash -c "$compiler $source_file"
    assert_json "$source_file" $compiler "$source_file"
  fi
}

function test_compiler_path2 {
  IFS=':' read -ra my_array <<< $PATH
  compiler=$(find ${my_array[@]} -name g++-* -print -quit)

  if [ -n $compiler ]; then
    CC_LOGGER_GCC_LIKE="/g++-" bash -c "$compiler $source_file"

    echo -ne "[\n]" > $reference_file
    diff $reference_file $CC_LOGGER_FILE
  fi
}

function test_simple {
  bash -c "g++ $source_file"

  assert_json "$source_file" g++ "$source_file"
}

function test_cpath {
  CPATH=path1 \
  bash -c "g++ $source_file"

  assert_json \
    "-I path1 $source_file" \
    g++ \
    "$source_file"
}

function test_cpath_after_last_I {
  CPATH=":path1:path2:" \
  bash -c "g++ -I p0 $source_file -I p1 -I p2"

  assert_json \
    "-I p0 $source_file -I p1 -I p2 -I . -I path1 -I path2 -I ." \
    g++ \
    "$source_file"
}

function test_cplus {
  CPLUS_INCLUDE_PATH="path1:path2" \
  C_INCLUDE_PATH="path3:path4" \
  bash -c "g++ -I p0 -isystem p1 $source_file"

  assert_json \
    "-I p0 -isystem p1 -isystem path1 -isystem path2 $source_file" \
    g++ \
    "$source_file"
}

function test_c {
  CPLUS_INCLUDE_PATH="path1:path2" \
  C_INCLUDE_PATH="path3:path4" \
  bash -c "gcc -I p0 -isystem p1 $source_file"

  assert_json \
    "-I p0 -isystem p1 -isystem path3 -isystem path4 $source_file" \
    gcc \
    "$source_file"
}

function test_cpp {
  CPLUS_INCLUDE_PATH="path1:path2" \
  C_INCLUDE_PATH="path3:path4" \
  bash -c "gcc -I p0 -isystem p1 -x c++ $source_file"

  assert_json \
    "-I p0 -isystem p1 -isystem path1 -isystem path2 -x c++ $source_file" \
    gcc \
    "$source_file"
}

function test_space {
  bash -c "gcc -DVARIABLE='hello world' $source_file"

  assert_json \
    "-DVARIABLE=hello\\\\ world $source_file" \
    gcc \
    "$source_file"
}

function test_quote {
  bash -c "gcc -DVARIABLE=\\\"hello\\\" $source_file"

  assert_json \
    "-DVARIABLE=\\\\\\\"hello\\\\\\\" $source_file" \
    gcc \
    "$source_file"
}

function test_space_quote {
  bash -c "gcc -DVARIABLE=\\\"hello\\ world\\\" $source_file"

  assert_json \
    "-DVARIABLE=\\\\\\\"hello\\\\ world\\\\\\\" $source_file" \
    gcc \
    "$source_file"
}

function test_response_file {
  echo "-I p0 -isystem p1" > $response_file
  bash -c "clang @$response_file $source_file"

  assert_json "@$response_file $source_file" clang "$source_file"
}

function test_response_file_contain_source_file {
  echo "-I p0 -isystem p1 $source_file" > $response_file
  bash -c "clang @$response_file"

  assert_json "@$response_file" clang "@$response_file"
}

function test_compiler_abs {
  bash -c "/usr/bin/gcc $source_file"

  assert_json \
    "$source_file" \
    /usr/bin/gcc \
    "$source_file"
}

function test_include_abs1 {
  CC_LOGGER_ABS_PATH=1 bash -c "gcc -Ihello $source_file"
  grep -- -I/.*hello $CC_LOGGER_FILE &> /dev/null
}

function test_include_abs2 {
  CC_LOGGER_ABS_PATH=1 bash -c "gcc -I hello $source_file"
  grep -- "-I /.*hello" $CC_LOGGER_FILE &> /dev/null
}

function test_include_abs3 {
  CC_LOGGER_ABS_PATH=1 bash -c "gcc -isystem=hello $source_file"
  grep -- "-isystem=/.*hello" $CC_LOGGER_FILE &> /dev/null
}

function test_source_abs {
  CC_LOGGER_ABS_PATH=1 bash -c "cd /tmp && gcc $source_file_name"
  grep -- "$source_file" $CC_LOGGER_FILE &> /dev/null
}

function test_valid_json {
  bash -c "gcc 2>/dev/null"
  echo -ne "[\n]" > $reference_file

  diff $reference_file $CC_LOGGER_FILE
}


#--- Run tests ---#

echo "int main() {}" > $source_file

for func in $(declare -F); do
  if [[ $func =~ test_ ]]; then
    rm -f $CC_LOGGER_FILE
    rm -rf $CC_LOGGER_DEBUG_FILE
    $func

    if [ $? -ne 0 ]; then
      echo Test failed: $func
      rm a.out
      exit 1
    fi
  fi
done

rm -f a.out
