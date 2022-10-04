#!/bin/bash

lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

starts_with() {
    [[ "${1:0:${#2}}" = "$2" ]]
}

ends_with() {
    [[ "${1:$((${#1} - ${#2}))}" = "$2" ]]
}

is_integer() {
    REGEX='^[0-9]+$'
    [[ "$1" =~ $REGEX ]]
}
