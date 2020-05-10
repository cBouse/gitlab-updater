#!/bin/bash
export LANG=en_US.UTF-8

# Define
E_FILE=/etc/gitlab/skip-auto-reconfigure
NAME=GitLab
ICON=gitlab
TEXT="GitLab was updated. Please check out what is changed on <https://about.gitlab.com/releases/categories/releases/|here>."
CHANNEL=channel-name
HOOK_URL=https://put.your.webhook.url
ANNOUNCE_TIME=09:00

# Function
function update() {
    # Update the GitLab package
    sudo yum -y install gitlab-ee

    # To Get the regular migrations and latest code in place
    sudo SKIP_POST_DEPLOYMENT_MIGRATIONS=true gitlab-ctl reconfigure

    # Once the node is updated and reconfigure finished successfully, complete the migrations along the command
    sudo gitlab-rake db:migrate

    # Hot reload unicorn, puma and sidekiq service
    sudo gitlab-ctl hup unicorn
    sudo gitlab-ctl hup puma
    sudo gitlab-ctl restart sidekiq

    # Done!
    echo "Complete GitLab update."
}

# Check update
echo "Check update GitLab EE package..."
sudo yum check-update gitlab-ee
result=$?

if [ $result -eq 100 ]; then
    echo "There are packages available for an update."
    if [ ! -e ${E_FILE} ]; then
        # Create an empty file at the path
        sudo touch ${E_FILE}
        echo "Create an empty file"
    fi

    # Update
    update || { echo "An error has occurred when updating."; exit 1; }

    # Post to slack
    echo 'curl -X POST --data-urlencode \
        "payload={\"channel\": \"#'${CHANNEL}'\", \"username\": \"'${NAME}'\", \"text\": \"'${TEXT}'\", \"icon_emoji\": \":'${ICON}':\"}" '${HOOK_URL}'' \
        | at "${ANNOUNCE_TIME} today" \
        || { echo "An error has occurred when posting to slack."; exit 1; }

elif [ $result -eq 0 ]; then
    # No packages to update
    echo "No packages are available for update."
else
    # Error
    echo "An error occurred."
fi