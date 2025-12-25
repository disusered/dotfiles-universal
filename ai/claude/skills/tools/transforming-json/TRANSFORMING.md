# Core Transformations

Operations for reshaping, constructing, and merging JSON structures.

## Reshaping Objects

### Rename and Extract Fields

```bash
# Simple renaming
echo '{"name":"Alice","age":30}' | jq '{username: .name, years: .age}'
# Output: {"username":"Alice","years":30}

# Extract subset with new names
echo '{"firstName":"Alice","lastName":"Smith","email":"alice@example.com"}' | jq '{user: .firstName, contact: .email}'
# Output: {"user":"Alice","contact":"alice@example.com"}

# Combine fields
echo '{"firstName":"Alice","lastName":"Smith"}' | jq '{fullName: "\(.firstName) \(.lastName)"}'
# Output: {"fullName":"Alice Smith"}
```

### Nested Restructuring

```bash
# Flatten nested structure
echo '{"user":{"profile":{"name":"Alice","email":"alice@example.com"},"id":123}}' | jq '{id: .user.id, name: .user.profile.name, email: .user.profile.email}'
# Output: {"id":123,"name":"Alice","email":"alice@example.com"}

# Create nested from flat
echo '{"id":123,"name":"Alice","email":"alice@example.com","city":"NYC"}' | jq '{id, user: {name, email}, location: {city}}'
# Output: {"id":123,"user":{"name":"Alice","email":"alice@example.com"},"location":{"city":"NYC"}}

# Restructure array of objects
jq '.users | map({userId: .id, profile: {name, email, active}})' data.json
```

## Array-Object Conversions

### Array to Object

```bash
# Convert array to object using field as key
echo '[{"id":"a","value":1},{"id":"b","value":2}]' | jq 'map({(.id): .value}) | add'
# Output: {"a":1,"b":2}

# Create object with computed keys
echo '[{"name":"Alice","score":95},{"name":"Bob","score":87}]' | jq 'map({(.name): .score}) | add'
# Output: {"Alice":95,"Bob":87}

# Use from_entries for key-value pairs
echo '[{"key":"name","value":"Alice"},{"key":"age","value":30}]' | jq 'from_entries'
# Output: {"name":"Alice","age":30}
```

### Object to Array

```bash
# Convert object to array of key-value pairs
echo '{"name":"Alice","age":30,"city":"NYC"}' | jq 'to_entries'
# Output: [{"key":"name","value":"Alice"},{"key":"age","value":30},{"key":"city","value":"NYC"}]

# Convert object to array of values
echo '{"a":1,"b":2,"c":3}' | jq '[.[] ]'
# Output: [1,2,3]

# Convert to custom format
echo '{"a":1,"b":2,"c":3}' | jq 'to_entries | map({name: .key, count: .value})'
# Output: [{"name":"a","count":1},{"name":"b","count":2},{"name":"c","count":3}]
```

## Merging and Combining

### Merge Objects

```bash
# Simple merge
echo '{"a":1,"b":2}' | jq '. + {"c":3,"d":4}'
# Output: {"a":1,"b":2,"c":3,"d":4}

# Override values
echo '{"a":1,"b":2}' | jq '. + {"b":5,"c":3}'
# Output: {"a":1,"b":5,"c":3}

# Merge nested objects
echo '{"user":{"name":"Alice"}}' | jq '.user += {"email":"alice@example.com"}'
# Output: {"user":{"name":"Alice","email":"alice@example.com"}}
```

### Combine Arrays

```bash
# Concatenate arrays
echo '{"a":[1,2],"b":[3,4]}' | jq '.a + .b'
# Output: [1,2,3,4]

# Merge array of objects
echo '[[{"a":1}],[{"b":2}]]' | jq 'add'
# Output: [{"a":1},{"b":2}]

# Flatten nested arrays
echo '[[1,2],[3,4],[5,6]]' | jq 'add'
# Output: [1,2,3,4,5,6]
```

## Building New Structures

### Construct From Scratch

```bash
# Build object with computed values
echo '{"price":100,"tax":0.1}' | jq '{price, tax, total: (.price * (1 + .tax))}'
# Output: {"price":100,"tax":0.1,"total":110}

# Create array from fields
echo '{"a":1,"b":2,"c":3}' | jq '[.a, .b, .c]'
# Output: [1,2,3]

# Build complex nested structure
echo '{"id":123,"name":"Alice"}' | jq '{data: {user: {id, name}, meta: {created: now | todate}}}'
```

### Transform with Map

```bash
# Reshape all array elements
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq 'map({user: .name, years: .age})'
# Output: [{"user":"Alice","years":30},{"user":"Bob","years":25}]

# Add computed field to each
echo '[{"price":100},{"price":200}]' | jq 'map(. + {discounted: (.price * 0.9)})'
# Output: [{"price":100,"discounted":90},{"price":200,"discounted":180}]
```

## Conditional Construction

### If-Then-Else in Construction

```bash
# Add field conditionally
echo '{"age":30}' | jq '. + {status: (if .age >= 18 then "adult" else "minor" end)}'
# Output: {"age":30,"status":"adult"}

# Different structures based on condition
jq 'if .type == "user" then {userId: .id, name} else {itemId: .id, title: .name} end' record.json

# Select fields conditionally
jq '{id, name, (if .premium then {tier: "premium", discount: .discount} else {} end)}' user.json
```
