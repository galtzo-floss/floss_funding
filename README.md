# FlossFunding

## TO DO List

## Configuration

Gems that use the floss_funding gem can configure some features by creating a `.floss_funding.yml` file at their root directory. This works in the same manner as `.rubocop.yml` for gems that use RuboCop.

### Configuration Options

The following options can be configured in the `.floss_funding.yml` file:

1. `suggested_donation_amount` - The suggested donation amount to display in the begging message (default: 5)
2. `funding_url` - The URL to direct users to for donations or sponsorship
   a. default: https://floss-funding.dev, which doesn't take donations on behalf of other projects, so it will have helpful tips on how to find a way to donate.

### Example Configuration

```yaml
suggested_donation_amount: 10
funding_url: https://example.com/fund
```

### Should Haves

- [ ] A website to generate activation keys for gems
  - [ ] List all known gems that can be activated with floss_funding
  - [ ] Account creation with email address, for those who want to keep a record of their generated activation keys
  - [ ] (Optional) Enter Gem Name
  - [ ] Affirm they have purchased an activation key
  - [ ] (Optional) Receive activation key specific to namespace & month generated
  - [x] Activation key will remain valid for that namespace forever (tested out to the June, 5425 C.E.)

### Nice to haves

- [] Poke will display random quote from a random philosopher.
