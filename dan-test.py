
# import the installed Jira library
from jira import JIRA
from atlassian import Jira
# Specify a server key. It should be your
# domain name link. yourdomainname.atlassian.net
spirentURL = "https://jira.spirenteng.com"

# will need to replace with Dan's token (not created yet and email)
dmeToken = "OTc5OTUyNDAzMzQ1Ohp8Hg9wIUsjZsOYeEFYTwCEordM"
dmeEmail = "derek.ealy@spirent.com"

jiraOptions = {'server': spirentURL}

jira = Jira(
    url=spirentURL,
    token=dmeToken)

#Search all issues mentioned against a project name.
for singleIssue in jira.search_issues(jql_str='project = "CIP - Firmware" and assignee = DEaly'):
	print('{}: {}:{}'.format(singleIssue.key, singleIssue.fields.summary,
							singleIssue.fields.reporter.displayName))


