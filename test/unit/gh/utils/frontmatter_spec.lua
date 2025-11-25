local frontmatter = require("gh.utils.frontmatter")

describe("utils.frontmatter", function()
  describe("parse", function()
    it("should parse valid frontmatter", function()
      local content = [[---
name: Bug Report
about: Report a bug
title: '[Bug] '
labels: bug
assignees: ''
---

## Bug Description

This is the body.]]

      local fm, body = frontmatter.parse(content)

      assert.is_not_nil(fm)
      assert.equals("Bug Report", fm.name)
      assert.equals("Report a bug", fm.about)
      assert.equals("'[Bug] '", fm.title) -- Single quotes preserved in raw parse
      assert.equals("bug", fm.labels)
      assert.is_nil(fm.assignees)
      assert.truthy(body:find("## Bug Description", 1, true))
    end)

    it("should handle content without frontmatter", function()
      local content = "# Regular markdown\n\nNo frontmatter here."
      local fm, body = frontmatter.parse(content)

      assert.is_nil(fm)
      assert.equals(content, body)
    end)

    it("should handle empty frontmatter values", function()
      local content = [[---
name: Test
assignees: ''
labels:
---

Body content]]

      local fm, body = frontmatter.parse(content)

      assert.is_not_nil(fm)
      assert.equals("Test", fm.name)
      assert.is_nil(fm.assignees)
      assert.is_nil(fm.labels)
    end)
  end)

  describe("parse_yaml", function()
    it("should parse simple key-value pairs", function()
      local yaml = [[name: Bug Report
title: '[Bug] '
labels: bug, urgent]]

      local result = frontmatter.parse_yaml(yaml)

      assert.equals("Bug Report", result.name)
      assert.equals("'[Bug] '", result.title) -- Single quotes preserved
      assert.equals("bug, urgent", result.labels)
    end)

    it("should handle quoted values", function()
      local yaml = [[name: "Bug Report"
title: '[Bug] ']]

      local result = frontmatter.parse_yaml(yaml)

      assert.equals("Bug Report", result.name) -- Double quotes removed
      assert.equals("'[Bug] '", result.title) -- Single quotes preserved
    end)

    it("should skip comments and empty lines", function()
      local yaml = [[# This is a comment
name: Test

# Another comment
title: Title]]

      local result = frontmatter.parse_yaml(yaml)

      assert.equals("Test", result.name)
      assert.equals("Title", result.title)
    end)
  end)

  describe("validate", function()
    it("should accept valid frontmatter fields", function()
      local fm = {
        name = "Bug Report",
        title = "[Bug] ",
        labels = "bug",
        assignees = "user1",
      }

      local valid, error = frontmatter.validate(fm)
      assert.is_true(valid)
      assert.is_nil(error)
    end)

    it("should reject invalid fields", function()
      local fm = {
        name = "Bug Report",
        invalid_field = "value",
      }

      local valid, err = frontmatter.validate(fm)
      assert.is_false(valid)
      assert.is_not_nil(err)
      assert.truthy(err:find("invalid_field", 1, true))
    end)

    it("should accept nil frontmatter", function()
      local valid, error = frontmatter.validate(nil)
      assert.is_true(valid)
      assert.is_nil(error)
    end)
  end)

  describe("extract_metadata", function()
    it("should extract title prefix", function()
      local fm = { title = "[Bug] " }
      local metadata = frontmatter.extract_metadata(fm)

      assert.equals("[Bug] ", metadata.title)
    end)

    it("should extract single label", function()
      local fm = { labels = "bug" }
      local metadata = frontmatter.extract_metadata(fm)

      assert.equals(1, #metadata.labels)
      assert.equals("bug", metadata.labels[1])
    end)

    it("should extract multiple labels", function()
      local fm = { labels = "bug, urgent, needs-triage" }
      local metadata = frontmatter.extract_metadata(fm)

      assert.equals(3, #metadata.labels)
      assert.equals("bug", metadata.labels[1])
      assert.equals("urgent", metadata.labels[2])
      assert.equals("needs-triage", metadata.labels[3])
    end)

    it("should extract assignees", function()
      local fm = { assignees = "user1, user2" }
      local metadata = frontmatter.extract_metadata(fm)

      assert.equals(2, #metadata.assignees)
      assert.equals("user1", metadata.assignees[1])
      assert.equals("user2", metadata.assignees[2])
    end)

    it("should handle empty assignees", function()
      local fm = { assignees = "" }
      local metadata = frontmatter.extract_metadata(fm)

      assert.equals(0, #metadata.assignees)
    end)

    it("should return empty metadata for nil frontmatter", function()
      local metadata = frontmatter.extract_metadata(nil)

      assert.is_nil(metadata.title)
      assert.equals(0, #metadata.labels)
      assert.equals(0, #metadata.assignees)
    end)
  end)
end)
