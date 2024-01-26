# This script takes the output of `rke2 server -h` and converts it to markdown tables
# Example: rke2 server -h | python3 help_to_markdown.py /dev/stdin > help.md

import sys
import re

filename = sys.argv[1]
is_agent = False
if len(sys.argv) == 3:
    is_agent = sys.argv[2] == "agent"


with open(filename, 'r') as file:
    lines = file.readlines()


def weirdGroups(group):
    if group == "db":
        group = "database"
    if group.startswith("experimental"):
        group = "experimental"
    if is_agent and group.startswith("agent/"):
        group = group.split("agent/")[1]
    if is_agent and group.startswith("flags"):
        group = "components"
    return group


def docusaurusFormat(string):
    if "<" in string:
        string = string.replace("<", "&lt;")
    if ">" in string:
        string = string.replace(">", "&gt;")

    if "{" in string:
        string = string.replace("{", "&#123;")
    if "}" in string:
        string = string.replace("}", "&#125;")
        
    return string

def constructHeader(value):
    has_env_var = any(env_var != "" for _, _, _, env_var in value)
    has_default = any(default != "" for _, _, default, _ in value)
    header = "| Flag | Description |"
    columns = "| --- | --- |"
    if has_default:
        header += " Default |"
        columns += " --- |"
    if has_env_var:
        header += " Enviroment Variable |"
        columns += " --- |"
    return header + "\n" + columns, has_default, has_env_var

found_options = False
# Dictionary of groups, each group has a list of tuples (key, description, default)
options_dict = {}
# Hardcode config flag because its got FILE, not value plus default and env var
options_dict["common"] = [("config", "Path to config file", "/etc/rancher/rke2/config.yaml", "RKE2_CONFIG_FILE")]

for line in lines:
    if not found_options:
        if "OPTIONS" in line:
            found_options = True
        continue

    if found_options:
        # This match handles flags with defaults and/or env vars
        match = re.search(r'--([\w\d-]+)\s(?:value|\s).*?\((.*?)\)\s+(.*?)(?:\(default: |\[)(.*)(?:\)|\])', line)
        if match:
            key = match.group(1)
            group = weirdGroups(match.group(2))
            description = match.group(3)
            # We don't want to catch ${data-dir}, so check second letter
            if match.group(4).startswith("$") and match.group(4)[1].isalpha():
                env_var = match.group(4).strip("$")
                default = ""
            # Case for default capture including an env var
            elif ") [$" in match.group(4):
                sections = match.group(4).split(") [$")
                default = sections[0]
                env_var = sections[1].strip("]")
            else:
                env_var = ""
                default = match.group(4)
                      
            if key == "data-dir" or key == "debug":
                group = "common"

            # Docusaurus doesn't like < or >
            default = docusaurusFormat(default)

            if group in options_dict:
                options_dict[group].append((key, description, default, env_var))
            else:
                options_dict[group] = [(key, description, default, env_var)]
        else:
            # This match handles flags with no defaults or env vars
            match = re.search(r'--([\w\d-]+)\s(?:value|\s).*?\((.*?)\)\s+(.*)$', line)
            if match:
                key = match.group(1)
                group = weirdGroups(match.group(2))
                description = match.group(3)
                default = ""
                env_var = ""
                
                if group in options_dict:
                    options_dict[group].append((key, description, "", ""))
                else:
                    options_dict[group] = [(key, description, "", "")]
                

agent_dict = {}

for group, value in options_dict.items():

    if group.startswith("agent") or group.startswith("experimental"):
        agent_dict[group] = options_dict[group]
        continue

    print(f"### {group.title()}")
    header, has_default, has_env = constructHeader(value)
    print(header)

    for key, description, default, env_var in value:
        if has_default and has_env:
            print(f"| {key} | {description} | {default} | {env_var} |")
        elif has_default:
            print(f"| {key} | {description} | {default} |")
        elif has_env:
            print(f"| {key} | {description} | {env_var} |")
        else:
            print(f"| {key} | {description} |")

for group, value in agent_dict.items():

    print(f"### {group.title()}")
    header, has_default, has_env = constructHeader(value)
    print(header)

    for key, description, default, env_var in value:
        if has_default and has_env:
            print(f"| {key} | {description} | {default} | {env_var} |")
        elif has_default:
            print(f"| {key} | {description} | {default} |")
        elif has_env:
            print(f"| {key} | {description} | {env_var} |")
        else:
            print(f"| {key} | {description} |")