#!/bin/bash

counter=1

while true; do
    echo "========================================"
    echo " Starting test iteration $counter"
    echo "========================================"

    # Run make, pipe output to both the screen and a temporary log file
    make -C top/i3c_ahb all MODULE=test_csr_access
    
    MAKE_EXIT=${PIPESTATUS[0]}

    # Check 1: Did the summary table report 1 or more failures? (Regex matches FAIL= followed by any non-zero number)
    if grep -qE "FAIL=[1-9]" current_run.log; then
        echo "========================================"
        echo "❌ Cocotb reported a FAIL on iteration $counter!"
        echo "========================================"
        break
    fi

    # Check 2: Did an AssertionError happen (just in case it crashed before the summary)?
    if grep -q "AssertionError" current_run.log; then
        echo "========================================"
        echo "❌ AssertionError detected on iteration $counter!"
        echo "========================================"
        break
    fi

    # Check 3: Did Make itself actually fail (e.g., compile error)?
    if [ $MAKE_EXIT -ne 0 ]; then
        echo "========================================"
        echo "❌ Make failed with exit code $MAKE_EXIT on iteration $counter!"
        echo "========================================"
        break
    fi

    echo "✅ Iteration $counter passed."
    ((counter++))
done
