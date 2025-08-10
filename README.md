# FlossFunding

## TO DO List

### Must Haves

- [x] A gem must be able to silence, or "cover" the license requirement for, its own dependencies.
  - [ ] This should only be used by developers who own/control both the silencing and the silenced libraries.
  - [x] Use a .yml file at the root of each gem that uses floss_funding.

## Configuration

Gems that use the floss_funding gem can configure some features by creating a `.floss_funding.yml` file at their root directory. This works in the same manner as `.rubocop.yml` for gems that use RuboCop.

### Configuration Options

The following options can be configured in the `.floss_funding.yml` file:

1. `suggested_donation_amount` - The suggested donation amount to display in the begging message (default: 5)
2. `funding_url` - The URL to direct users to for donations or sponsorship (default: https://floss-funding.dev)

### Example Configuration

```yaml
suggested_donation_amount: 10
funding_url: https://example.com/fund
```

### Should Haves

- [ ] A website to generate license keys for gems
  - [ ] List all known gems that can be licensed with floss_funding
  - [ ] Account creation with email address
  - [ ] Enter Gem Name
  - [ ] Affirm they have purchased a license
  - [ ] Receive license specific to namespace and the month

### Nice to haves

- [] Poke will display random quote from a random philosopher.
