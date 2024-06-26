#!/bin/bash

# Source the .env file to load the variables.
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

# This script automates the process of updating Dockerfile base images in a specific Git repository.
# It navigates to the repository directory, selects a branch, updates the Dockerfile, and commits and pushes these changes.

# Function to navigate to the repository directory.
# It checks if the directory exists and navigates into it. If a subdirectory named 'profile-service' exists, it navigates into it as well.
navigate_to_repo() {
    cd $BASE_REPO_DIR || { echo "Directory $BASE_REPO_DIR does not exist." >> $OUTPUT_FILE; exit 1; }

    # Check for a specific subdirectory structure and navigate if necessary.
    if [ $(ls -1 | wc -l) -eq 1 ] && [ -d "profile-service" ]; then
        cd profile-service || { echo "Failed to navigate to subdirectory 'profile-service'." >> $OUTPUT_FILE; exit 1; }
    fi
}

# Function to select the Git branch where updates will be made.
# It sets a branch name, fetches the latest branches from the remote, and checks if the specified branch exists.
# If the branch exists locally, it checks it out and pulls the latest changes. Otherwise, it creates and checks out a new branch from the remote.
select_branch() {
    local branch_name=$BRANCH_NAME
    local repo_name=$(basename `git rev-parse --show-toplevel`)

    # Clean up stale remote branch references and fetch the latest branch information.
    git remote prune origin
    git fetch --all

    # Check for the existence of the branch in the remote repository.
    if git show-ref --verify --quiet refs/remotes/origin/$branch_name; then
        # Branch exists remotely, now check locally.
        if git rev-parse --verify --quiet "$branch_name"; then
            echo "Branch '$branch_name' exists locally. Checking out and pulling the latest changes..." >> $OUTPUT_FILE
            git checkout $branch_name
            git pull origin $branch_name
        else
            echo "Branch '$branch_name' does not exist locally. Creating and checking out..." >> $OUTPUT_FILE
            git checkout -b $branch_name origin/$branch_name
        fi
    else
        echo "No remote branch found '$branch_name' for repository '$repo_name'" >> $OUTPUT_FILE
        exit 1
    fi
}

# Function to update the Dockerfile with new base images.
# It checks for the existence of the Dockerfile, then searches and replaces specific base image references with new ones.
# After updating, it commits and pushes the changes to a new branch.
update_dockerfile() {
    local dockerfile_path=$DOCKERFILE_PATH

    # Ensure the Dockerfile exists before attempting updates.
    if [ ! -f $dockerfile_path ]; then
        echo "Dockerfile not found in $BASE_REPO_DIR" >> $OUTPUT_FILE
        exit 1
    fi

    # Search for specific base images and update their references.
    # The script supports updating multiple base images.
    if grep -q $OLD_IMAGE_1 $dockerfile_path; then
        sed -i "s|$OLD_IMAGE_1|$NEW_IMAGE_1|g" $dockerfile_path
        echo "Updated '$OLD_IMAGE_1' to '$NEW_IMAGE_1' in Dockerfile" >> $OUTPUT_FILE
    fi
    if grep -q $OLD_IMAGE_2 $dockerfile_path; then
        sed -i "s|$OLD_IMAGE_2|$NEW_IMAGE_2|g" $dockerfile_path
        echo "Updated '$OLD_IMAGE_2' to '$NEW_IMAGE_2' in Dockerfile" >> $OUTPUT_FILE
    fi
    if grep -q $OLD_IMAGE_3 $dockerfile_path; then
        sed -i "s|$OLD_IMAGE_3|$NEW_IMAGE_3|g" $dockerfile_path
        echo "Updated '$OLD_IMAGE_3' to '$NEW_IMAGE_3' in Dockerfile" >> $OUTPUT_FILE
    fi

    # Commit and push the changes to a new branch for review.
    local new_branch_name=$NEW_BRANCH_NAME
    git checkout -b $new_branch_name
    git add $dockerfile_path
    git commit -m "Updating Dockerfile images with internal versions"
    if ! git push; then
        echo "Pushing to new branch, --set-upstream push" >> $OUTPUT_FILE
        git push --set-upstream origin $new_branch_name
    fi
    echo "Push completed for repository $(basename `git rev-parse --show-toplevel`)"
}

# Main script execution block.
# It calls the defined functions in order to navigate to the repository, select the branch, update the Dockerfile, and log the operations.
{
    navigate_to_repo
    select_branch
    update_dockerfile

    echo "Dockerfile update completed for branch '$BRANCH_NAME'."
} >> $OUTPUT_FILE 2>&1