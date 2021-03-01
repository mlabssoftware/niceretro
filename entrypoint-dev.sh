#!/bin/bash -i
bundle check || bundle install

"$@"
