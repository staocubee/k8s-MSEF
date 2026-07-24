#!/usr/bin/env bash

###############################################################################
# Metric Library
###############################################################################

admission_blocked() {

    echo "$1" | grep -Eiq \
        "denied|forbidden|violation|violates|admission webhook|failed validation|required|not allowed|disallowed"

}

score() {

    awk -v a="$1" -v b="$2" \
        'BEGIN{
            if(b==0)
                print "0.00";
            else
                printf "%.2f",a/b
        }'

}

average3() {

    awk \
        -v a="$1" \
        -v b="$2" \
        -v c="$3" \
        'BEGIN{
            printf "%.2f",(a+b+c)/3
        }'

}
