# Stage Summary

## 1. Stage Description
Fix CI registry dependency resolution by replacing deprecated `moon install` with `moon update`.

## 2. Stage Metadata
- STAGE_ID: fix_ci_registry
- STAGE_TYPE: fix
- BASE_COMMIT: b8af1f7c5e6107ce98bead31a4ce3d3611b8b62d

## 3. Modified Files
1. .github/workflows/ci.yml

## 4. Modified File Diffs
```
diff --git a/.github/workflows/ci.yml b/.github/workflows/ci.yml
index 567db29..91b5193 100644
--- a/.github/workflows/ci.yml
+++ b/.github/workflows/ci.yml
@@ -16,8 +16,8 @@ jobs:
       - name: Setup MoonBit
         uses: hustcer/setup-moonbit@v1
 
-      - name: Install Dependencies
-        run: moon install
+      - name: Update Registry Index
+        run: moon update
 
       - name: Check
         run: moon check
```

## 5. ACTION_LOG
- Modified `.github/workflows/ci.yml`: Replaced deprecated `moon install` with `moon update` to ensure registry index is current before resolving `moonbitlang/regexp@0.3.5`

## 6. Risks / Notes
- No risk; `moon update` is the recommended replacement for `moon install` for updating registry index before building/testing.
