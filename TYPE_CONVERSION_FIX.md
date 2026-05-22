# Type Conversion Fix - SMC_Universal.mq5

## Issue
Compilation warning: "possible loss of data due to type conversion from 'double' to 'int'"

## Root Cause
`StringToCharArray()` expects an `int` for the length parameter, but MQL5 compiler was treating the `StringLen()` return value as potentially ambiguous in certain contexts.

## Solution
Added explicit `(int)` cast to all `StringLen()` calls used as parameters to `StringToCharArray()`.

## Changes Made

### Lines Fixed (6 instances):
1. Line 14529: `StringToCharArray(payload, post_data, 0, (int)StringLen(payload));`
2. Line 14690: `StringToCharArray(payload, post, 0, (int)StringLen(payload));`
3. Line 18654: `StringToCharArray(json_payload, post_data, 0, (int)StringLen(json_payload));`
4. Line 19938: `StringToCharArray(json_payload, post_data, 0, (int)StringLen(json_payload));`
5. Line 25282: `StringToCharArray(jsonOut, postOut, 0, (int)StringLen(jsonOut));`
6. Line 25323: `StringToCharArray(jsonLog, postLog, 0, (int)StringLen(jsonLog));`

## Pattern Changed
```mql5
// BEFORE (warning)
StringToCharArray(str, arr, 0, StringLen(str));

// AFTER (no warning)
StringToCharArray(str, arr, 0, (int)StringLen(str));
```

## Impact
- Minimal code change
- No functional behavior change
- Resolves compiler warning
- Follows MQL5 best practices for type safety

## Verification
Run compilation script:
```bash
compile_smc_universal.bat
```

Expected result: 0 errors, 0 warnings
