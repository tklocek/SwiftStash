#!/usr/bin/env python3
"""Render the xUnit files produced by `swift test --xunit-output` as Markdown.

Usage: test-summary.py <directory-with-xml-files>

Prints a results table (and the list of failed tests, if any) to stdout;
CI appends it to $GITHUB_STEP_SUMMARY. `swift test` writes one file for
XCTest and a `*-swift-testing.xml` sibling for Swift Testing suites —
both are picked up here.
"""
import glob
import sys
import xml.etree.ElementTree as ET

directory = sys.argv[1] if len(sys.argv) > 1 else "."
files = sorted(glob.glob(f"{directory}/*.xml"))
if not files:
    print("## Test results\n\nNo xUnit output found — the test step "
          "probably failed before producing results.")
    sys.exit(0)

total = failures = errors = skipped = 0
time = 0.0
failed_cases = []

for path in files:
    root = ET.parse(path).getroot()
    suites = [root] if root.tag == "testsuite" else root.iter("testsuite")
    for suite in suites:
        total += int(suite.get("tests", 0))
        failures += int(suite.get("failures", 0))
        errors += int(suite.get("errors", 0))
        skipped += int(suite.get("skipped", 0))
        time += float(suite.get("time", 0))
        for case in suite.iter("testcase"):
            if case.find("failure") is not None or case.find("error") is not None:
                name = f'{case.get("classname", "")}.{case.get("name", "")}'.lstrip(".")
                message = None
                for tag in ("failure", "error"):
                    element = case.find(tag)
                    if element is not None:
                        message = element.get("message")
                        break
                failed_cases.append((name, message))

passed = total - failures - errors - skipped
verdict = "✅ All tests passed" if not failed_cases else "❌ Tests failed"

print(f"## {verdict}\n")
print("| Total | Passed | Failed | Skipped | Time |")
print("|------:|-------:|-------:|--------:|-----:|")
print(f"| {total} | {passed} | {failures + errors} | {skipped} | {time:.1f}s |")

if failed_cases:
    print("\n### Failed tests\n")
    for name, message in failed_cases:
        detail = f" — {message}" if message else ""
        print(f"- `{name}`{detail}")
