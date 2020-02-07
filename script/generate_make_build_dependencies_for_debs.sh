#!/bin/sh

for list in $CONFIG_PATH
do
  cat "$project_root/config/$list/build_dependencies" 2>/dev/null || true
  cat "$project_root/config/$list/build_dependencies/"* 2>/dev/null || true
done |
  while IFS=':' read targets prerequisites
    do for target in $targets
      do for prerequisite in $prerequisites
        do echo "$DEP_PREFIX$target$DEP_SUFFIX: $DEP_PREFIX$prerequisite$DEP_SUFFIX"
      done
    done
  done
