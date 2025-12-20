#!/bin/bash

# Script to merge all open PRs from upstream into local integration-test
# This will merge all your PR branches that are currently open on Freetz-NG/freetz-ng
# 
# Usage:
#   ./merge_all_prs.sh                    # Merge all open PRs
#   ./merge_all_prs.sh 1293 1292 1291    # Merge specific PRs by number

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Merging all open PRs into integration-test ===${NC}"
echo ""

# Check if specific PRs were provided as arguments
if [ $# -gt 0 ]; then
    # Merge specific PRs
    echo -e "${GREEN}Fetching details for specified PRs: $@${NC}"
    pr_numbers="$@"
    
    # Build JSON array of PR data
    prs="["
    first=true
    for pr_num in $pr_numbers; do
        if [ "$first" = true ]; then
            first=false
        else
            prs+=","
        fi
        
        pr_data=$(gh pr view "$pr_num" --repo Freetz-NG/freetz-ng --json number,title,headRefName 2>/dev/null || echo "")
        if [ -z "$pr_data" ]; then
            echo -e "${RED}Warning: PR #$pr_num not found, skipping...${NC}"
            continue
        fi
        prs+="$pr_data"
    done
    prs+="]"
    
    if [ "$prs" = "[]" ]; then
        echo -e "${RED}No valid PRs found.${NC}"
        exit 1
    fi
else
    # Get list of all open PRs
    echo -e "${GREEN}Fetching list of all open PRs...${NC}"
    prs=$(gh pr list --repo Freetz-NG/freetz-ng --state open --json number,title,headRefName --limit 100)
    
    if [ -z "$prs" ] || [ "$prs" = "[]" ]; then
        echo -e "${YELLOW}No open PRs found.${NC}"
        exit 0
    fi
fi

# Extract branch names
branches=$(echo "$prs" | jq -r '.[].headRefName')

echo -e "${GREEN}Found the following PR branches:${NC}"
echo "$prs" | jq -r '.[] | "  PR #\(.number): \(.headRefName) - \(.title)"'
echo ""

# Ask for confirmation
read -p "Do you want to merge all these branches into integration-test? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Merge cancelled.${NC}"
    exit 0
fi

# Delete existing integration-test branch if it exists
if git show-ref --verify --quiet "refs/heads/integration-test"; then
    echo -e "${YELLOW}Deleting existing integration-test branch...${NC}"
    git branch -D integration-test
fi

# Create new integration-test branch from upstream/master
echo -e "${GREEN}Creating new integration-test branch from upstream/master...${NC}"
git checkout -b integration-test upstream/master

# Ensure we're on integration-test
current_branch=$(git branch --show-current)
if [ "$current_branch" != "integration-test" ]; then
    echo -e "${RED}Error: Not on integration-test branch!${NC}"
    exit 1
fi

# Merge each branch
echo ""
echo -e "${GREEN}Starting merge process...${NC}"
echo ""

failed_merges=()
successful_merges=()

while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Merging branch: $branch${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Check if branch exists locally
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        echo -e "${YELLOW}Branch exists locally, updating...${NC}"
        git checkout "$branch"
        git pull origin "$branch" || {
            echo -e "${RED}Failed to update branch $branch${NC}"
            git checkout integration-test
            failed_merges+=("$branch (update failed)")
            continue
        }
    else
        echo -e "${YELLOW}Branch doesn't exist locally, fetching...${NC}"
        git fetch origin "$branch:$branch" || {
            echo -e "${RED}Failed to fetch branch $branch${NC}"
            failed_merges+=("$branch (fetch failed)")
            continue
        }
    fi
    
    # Switch back to integration-test
    git checkout integration-test
    
    # Attempt merge
    if git merge --no-ff "$branch" -m "Merge branch '$branch'"; then
        echo -e "${GREEN}✓ Successfully merged $branch${NC}"
        successful_merges+=("$branch")
    else
        echo -e "${RED}✗ Merge conflict in $branch${NC}"
        echo -e "${YELLOW}Aborting merge...${NC}"
        git merge --abort
        failed_merges+=("$branch (merge conflict)")
    fi
    
    echo ""
done <<< "$branches"

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Merge Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ ${#successful_merges[@]} -gt 0 ]; then
    echo -e "${GREEN}Successfully merged (${#successful_merges[@]}):${NC}"
    for branch in "${successful_merges[@]}"; do
        echo -e "  ${GREEN}✓${NC} $branch"
    done
    echo ""
fi

if [ ${#failed_merges[@]} -gt 0 ]; then
    echo -e "${RED}Failed merges (${#failed_merges[@]}):${NC}"
    for branch in "${failed_merges[@]}"; do
        echo -e "  ${RED}✗${NC} $branch"
    done
    echo ""
    echo -e "${YELLOW}You may need to resolve conflicts manually for failed merges.${NC}"
fi

echo ""
if [ ${#successful_merges[@]} -gt 0 ]; then
    echo -e "${GREEN}Integration-test has been updated with ${#successful_merges[@]} PR branches.${NC}"
    echo -e "${YELLOW}Don't forget to push to origin if you want to update the remote:${NC}"
    echo -e "  ${YELLOW}git push origin integration-test${NC}"
fi

exit 0
