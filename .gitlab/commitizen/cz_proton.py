import re, os, textwrap

from commitizen.cz.base import BaseCommitizen
from commitizen import cmd, config
from commitizen.cz.utils import required_validator, multiple_line_breaker
from commitizen.cz.exceptions import CzException

__all__ = ["ProtonCz"]

class ProtonCz(BaseCommitizen):
    jira_regex = "[A-Z]{2,10}-[0-9]{2,5}"
    # Match the beginning of the string, or any character that isn't a dash, number, or uppercase letter, followed by between 2 and 5 numbers.
    # If `jira_prefix` is specified in config, this value will be prepended to the captured numbers and the result will be interpreted as a jira id.
    nums_regex = "(^|[^\-0-9A-Z])([0-9]{2,5})"
    conf = config.read_cfg()
    jira_prefix = conf.settings.get("jira_prefix")

    def questions(self) -> list:
        questions = [
            {
                "type": "list",
                "name": "prefix",
                "message": "Select the type of change you are committing.",
                "choices": [
                    {
                        "value": "fix",
                        "name": "fix: Introduces a bug fix. The next release will have an incremented patch version.",
                    },
                    {
                        "value": "feat",
                        "name": "feat: Introduces a new feature. The next release will have an incremented minor version.",
                    },
                    {
                        "value": "docs",
                        "name": "docs: Changes documentation only."
                    },
                    {
                        "value": "style",
                        "name": "style: Changes code formatting only: white-space, formatting, etc.",
                    },
                    {
                        "value": "refactor",
                        "name": "refactor: Changes code, but does not introduce a fix nor a feature."
                    },
                    {
                        "value": "perf",
                        "name": "perf: Introduces a performance improvement.",
                    },
                    {
                        "value": "test",
                        "name": "test: Adds one or more new tests, or fixes an existing one.",
                    },
                    {
                        "value": "build",
                        "name":  "build: Changes the build system or external dependencies, such as pods."
                    },
                    {
                        "value": "ci",
                        "name": "ci: Changes the Gitlab CI configuration.",
                    },
                    {
                        "value": "chore",
                        "name": "chore: Performs a routine task that isn't worth tracking, like a manual version bump.",
                    },
                ],
            },
            {
                "type": "input",
                "name": "scope",
                "message": ("Specify the scope of the change in one lowercase word (press [enter] to skip). "
                            "Examples might include 'api', 'mocks', 'ui', or 'config'."),
                "filter": self.validate_scope,
            },
            {
                "type": "input",
                "name": "subject",
                "filter": self.validate_subject,
                "message": ("Write a short, imperative summary of the code changes. For example, "
                            "'Move common elements of view model to separate library'\n"),
            },
            {
                "type": "input",
                "name": "body",
                "message": "Commit body providing additional context of changes, if necessary (press [enter] to skip)\n",
                "filter": self.wrap_commit_body,
            },
            {
                "type": "input",
                "message": ("Does this commit have breaking changes? If no, press [enter] to skip. If yes, enter some "
                            "short details about the breakage. The next release will have an incremented major version.\n"),
                "name": "breaking_changes",
            },
            {
                "type": "input",
                "message": "What Jira ID(s) are associated with this change? (press [enter] to skip)",
                "name": "jiraids",
                "default": self.get_jira_ids_string_from_env_or_branch(),
                "filter": self.validate_jiraids
            }
        ]

        return questions

    def wrap_commit_body(self, body):
        """
        Wrap the commit body to 72 characters.
        """

        body = multiple_line_breaker(body)

        return "\n".join(textwrap.wrap(body, width=72))


    def validate_subject(self, subject):
        """
        Makes sure that the user has entered a subject, and that it contains no periods.
        """
        if isinstance(subject, str):
            subject = subject.strip().strip(".") # strip trailing newline, then trailing period if it's there

        return required_validator(subject, msg="Subject is a required field.")

    def validate_scope(self, scope):
        """
        Makes sure that the scope is one word and all-lowercase.
        """

        # Allow field to be empty
        if not scope:
            return scope

        scope = scope.strip() # remove trailing newline

        if scope.lower() != scope:
            raise InvalidInputException(f"Scope '{scope}' should be all-lowercase.")
        if len(scope.split()) > 1:
            raise InvalidInputException(f"Scope '{scope}' should be one word.")

        return scope

    def extract_jiraids(self, jiraidstr):
        """
        Extracts one or more Jira IDs from a string. If the `jira_prefix` value is set in the config, then this function will allow
        "naked" IDs specified without a project prefix, and will interpret them as beginning with the `jira_prefix` config value.
        """

        jiraids = re.findall(self.jira_regex, jiraidstr)
        if isinstance(self.jira_prefix, str):
            # Get the first match group of each item and prepend with jira_prefix
            idnums = re.findall(self.nums_regex, jiraidstr)
            jiraids += map(lambda x: self.jira_prefix + "-" + x[1], idnums)

        return jiraids

    def validate_jiraids(self, jiraidstr):
        """
        Makes sure that the user is passing valid jira ids, if any are specified.
        """
        # Allow field to be empty
        if not jiraidstr:
            return jiraidstr

        jiraidstr = jiraidstr.strip() # remove any trailing newline(s)
        jiraids = self.extract_jiraids(jiraidstr)

        if not jiraids:
            raise InvalidInputException(f"Jira ID(s) '{jiraidstr}' not valid, should match the regex '{self.jira_regex}' at least once")

        return jiraids

    def get_branch_name(self):
        e = os.environ.get("CI_MERGE_REQUEST_SOURCE_BRANCH_NAME")
        if isinstance(e, str):
            return e

        e = os.environ.get("CI_COMMIT_BRANCH")
        if isinstance(e, str):
            return e
            
        c = cmd.run("git rev-parse --abbrev-ref HEAD")
        if c.out is not None:
            return c.out

        return None


    def get_jira_ids_from_env_or_branch(self):
        """
        Tries to extract Jira ID(s) from a CI variable, or from the current branch.
        """
        branch_name = self.get_branch_name()
        if branch_name is None:
            return None

        jiraids = self.extract_jiraids(branch_name)
        if not jiraids:
            return None

        return jiraids

    def get_jira_ids_string_from_env_or_branch(self):
        jiraids = self.get_jira_ids_from_env_or_branch()
        if not jiraids:
            return None

        return ", ".join(jiraids)

    def message(self, answers: dict) -> str:
        """
        Creates the commit message from the answers provided.
        """

        prefix = answers["prefix"]
        subject = answers["subject"]
        jiraids = answers["jiraids"]
        scope = answers["scope"]
        body = answers["body"]
        breaking_changes = answers["breaking_changes"].strip()

        header = prefix
        trailer = "\n\n"
        if breaking_changes:
            trailer += f"BREAKING CHANGES: {breaking_changes}\n"
        if jiraids:
            trailer += "\n".join([f"Jira-Id: {jiraid}" for jiraid in jiraids])

        if scope:
            header += f"({scope}): "
        else:
            header += ": "

        if body:
            body = "\n\n" + body

        header += subject

        return f"{header}{body}{trailer}".strip()

    def schema_pattern(self) -> str:
        """
        Define a regular expression that must match the commit message while linting.
        """

        regex = (
            r"(fix|feat|docs|style|refactor|perf|test|build|ci|chore|revert)" # prefix
            r"(\(\S+\))?!?:(\s.*)"     # scope and subject
            r"([\r\n][\r\n](.*)){0,1}" # commit body
            r"([\r\n][\r\n](.*\n)*)*"  # zero or more commit trailers
        )

        # If the branch mentions a jira id, the commit body should include it
        jiraids = self.get_jira_ids_from_env_or_branch()
        if jiraids:
            regex += "[\r\n]".join([f"(Jira-Id: {jiraid})" for jiraid in jiraids])

        return regex

    def schema(self) -> str:
        return (
            "<type>(<scope>): <subject>\n\n"
            "<body>\n\n"
            "BREAKING CHANGE: <details>\n"
            "Jira-Id: <jiraid>"
        )

    def example(self) -> str:
        return (
            "fix(viewer): De-frobulate splines in encabulator\n\n"
            "The encabulator's splines were reticulating when the viewer opened,\n"
            "causing the allocator to fragment the heap. Defrobulating avoids\n"
            "this issue by recalibrating the affinity of the block splitter.\n\n"
            "Jira-Id: JIRAID-1234"
        )


class InvalidInputException(CzException):
    ...


discover_this = ProtonCz
