#!/bin/bash

lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

starts_with() {
    [[ "${1:0:${#2}}" = "$2" ]]
}

is_integer() {
    REGEX='^[0-9]+$'
    [[ "$1" =~ $REGEX ]]
}
