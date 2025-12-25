# JSON Filtering and Selection

Advanced filtering operations for parsing JSON data.

## Select with Conditions

### Basic Selection

```bash
# Filter objects matching condition
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq '.[] | select(.age > 26)'
# Output: {"name":"Alice","age":30}

# Select from array
echo '[1,2,3,4,5]' | jq 'map(select(. > 2))'
# Output: [3,4,5]
```

### Multiple Conditions

```bash
# AND conditions
jq '.[] | select(.age > 20 and .name == "Alice")' users.json

# OR conditions
jq '.[] | select(.status == "active" or .status == "pending")' items.json

# NOT condition
jq '.[] | select(.deleted | not)' items.json
```

### Key Existence

```bash
# Check if key exists
echo '{"name":"Alice"}' | jq 'has("name")'
# Output: true

# Filter by key existence
jq '.[] | select(has("optional_field"))' data.json

# Check multiple keys
jq '.[] | select(has("name") and has("email"))' users.json
```

## Map Operations

### Transform Elements

```bash
# Map with arithmetic
echo '[1,2,3,4,5]' | jq 'map(. * 2)'
# Output: [2,4,6,8,10]

# Map to extract field
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq 'map(.name)'
# Output: ["Alice","Bob"]

# Map with select (filter + transform)
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq 'map(select(.age > 26) | .name)'
# Output: ["Alice"]
```

### Map to Objects

```bash
# Construct objects from array
echo '["alice","bob"]' | jq 'map({name: ., status: "active"})'
# Output: [{"name":"alice","status":"active"},{"name":"bob","status":"active"}]

# Extract specific fields
jq 'map({id: .id, name: .name})' users.json
```

## Conditional Logic

### If-Then-Else

```bash
# Simple conditional
jq '.[] | if .age >= 18 then "adult" else "minor" end' users.json

# With field assignment
jq '.[] | .category = if .price > 100 then "premium" else "standard" end' products.json
```

### Complex Conditionals

```bash
# Multiple conditions
jq 'if .status == "active" then .price * 0.9 elif .status == "pending" then .price else .price * 1.1 end' item.json

# Nested conditionals
jq 'if .user then (if .user.premium then "premium" else "basic" end) else "guest" end' session.json
```

## Alternative Operator (//)

### Default Values

```bash
# Use default if null or false
echo '{"a":null,"b":"value"}' | jq '.a // "default"'
# Output: "default"

# Chain alternatives
jq '.primary // .secondary // .fallback // "none"' data.json

# With field access
jq '.user.email // .contact.email // "no email"' record.json
```

## Unique and Sort

### Remove Duplicates

```bash
echo '[1,2,2,3,3,3]' | jq 'unique'
# Output: [1,2,3]

# Unique objects by field
jq 'unique_by(.category)' items.json
```

### Sort Arrays

```bash
# Sort numbers/strings
echo '[3,1,4,1,5]' | jq 'sort'
# Output: [1,1,3,4,5]

# Sort objects by field
jq 'sort_by(.age)' users.json

# Reverse sort
jq 'sort_by(.age) | reverse' users.json
```

## Group By

```bash
# Group by field
jq 'group_by(.category)' items.json
# Output: [[{items with category A}], [{items with category B}]]

# Group and count
jq 'group_by(.category) | map({category: .[0].category, count: length})' items.json
# Output: [{"category":"A","count":5},{"category":"B","count":3}]

# Group and sum
jq 'group_by(.category) | map({category: .[0].category, total: map(.price) | add})' items.json
```

## Empty and Error Handling

### Skip Empty Results

```bash
# Skip null/empty values
jq '.[] | .optional_field // empty' data.json

# Filter out nulls from array
jq '[.[] | select(. != null)]' array.json
```

### Try-Catch

```bash
# Try expression, use alternative on error
jq '.field | try . catch "error"' data.json

# Try with default
jq 'try .complex.nested.field catch null' data.json
```
