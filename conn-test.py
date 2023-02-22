# import the installed Jira library
from jira import JIRA
from atlassian import Jira
# Specify a server key. It should be your
# domain name link. yourdomainname.atlassian.net
spirentURL = "https://jira.spirenteng.com"
#dmeToken = "OTc5OTUyNDAzMzQ1Ohp8Hg9wIUsjZsOYeEFYTwCEordM"
dmeToken = "ODM4MzMzMzkxMTY1OpNnoFIggxYK8qx/oys8thx2zFj8"
dmeEmail = "derek.ealy@spirent.com"

jiraOptions = {'server': spirentURL}

# Adding some comments to the file
# Here we can contribute to the conflict
# Th' th' th' that's all folks
# Yaba daba doo!
# I need to come back and revisit this project

# Get a JIRA client instance, pass,
# Authentication parameters
# and the Server name.
# emailID = your emailID
# token = token you receive after registration
#jira = JIRA(options=jiraOptions, basic_auth=(dmeEmail, dmeToken, ))

jira = Jira(
    url=spirentURL,
    token=dmeToken)
# Search all issues mentioned against a project name.
# for singleIssue in jira.search_issues(jql_str='project = "CIP - Firmware" and asignee = DEaly'):
# 	print('{}: {}:{}'.format(singleIssue.key, singleIssue.fields.summary,
# 							singleIssue.fields.reporter.displayName))

issue = jira.issue('cipfw-1266', expand='changelog')
print("Found issue: ", issue)
#print("reporter: ", jira.issue_field_value('MANTIS-214', 'reporter')['name'])

# jql_request = 'project = "CIP - Firmware" and assignee = DEaly'
# issues = jira.jql(jql_request)
# for issue in jira.jql(jql_request):
#     print('{}: {}:{}'.format(issue.key, issue.fields.summary,
# 						 issue.fields.reporter.displayName))

def get_sprint_items(history_items):
#    print("hist: ", history_items) 
    items = filter(lambda i: i['field'] == 'Sprint', history_items)
    return list(items)

def has_sprint_change(history):
    sprint_items = filter(lambda h: get_sprint_items(h['items']), history)
    return list(sprint_items)

#print(issues)


                 # { 'author': { 'active': True,
                 #               'avatarUrls': { '16x16': 'https://jira.spirenteng.com/secure/useravatar?size=xsmall&ownerId=JIRAUSER47796&avatarId=24017',
                 #                               '24x24': 'https://jira.spirenteng.com/secure/useravatar?size=small&ownerId=JIRAUSER47796&avatarId=24017',
                 #                               '32x32': 'https://jira.spirenteng.com/secure/useravatar?size=medium&ownerId=JIRAUSER47796&avatarId=24017',
                 #                               '48x48': 'https://jira.spirenteng.com/secure/useravatar?ownerId=JIRAUSER47796&avatarId=24017'},
                 #               'displayName': 'Ealy, Derek',
                 #               'emailAddress': 'Derek.Ealy@spirent.com',
                 #               'key': 'JIRAUSER47796',
                 #               'name': 'DEaly',
                 #               'self': 'https://jira.spirenteng.com/rest/api/2/user?username=DEaly',
                 #               'timeZone': 'America/Los_Angeles'},
                 #   'created': '2022-05-09T19:36:03.000+0000',
                 #   'id': '4511124',
                 #   'items': [ { 'field': 'Sprint',
                 #                'fieldtype': 'custom',
                 #                'from': '2453',
                 #                'fromString': 'Apr 19 - May 9',
                 #                'to': '2518',
                 #                'toString': 'May 10 - May 30'}]},)
