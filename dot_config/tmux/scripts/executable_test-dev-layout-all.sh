#!/usr/bin/env bash
# Test layout automation across multiple Developer projects

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Testing Developer Layout Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Find a few projects to test (pick first 3 directories)
TEST_PROJECTS=($(ls -1 ~/Developer | head -3))

if [ ${#TEST_PROJECTS[@]} -eq 0 ]; then
    echo -e "${RED}No projects found in ~/Developer${NC}"
    exit 1
fi

echo "Found ${#TEST_PROJECTS[@]} projects to test:"
for proj in "${TEST_PROJECTS[@]}"; do
    echo "  - $proj"
done
echo ""

# Test each project
PASSED=0
FAILED=0

for project in "${TEST_PROJECTS[@]}"; do
    echo -e "${YELLOW}Testing: $project${NC}"
    echo "---"

    if ~/.config/tmux/scripts/test-dev-layout.sh "$project"; then
        ((PASSED++))
        echo -e "${GREEN}✓ $project passed${NC}"
    else
        ((FAILED++))
        echo -e "${RED}✗ $project failed${NC}"
    fi
    echo ""
done

# Summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! Your Developer project layout automation is working correctly.${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the configuration.${NC}"
    exit 1
fi
