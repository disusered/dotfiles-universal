# Advanced Transformations

Complex transformation patterns including recursion, custom functions, and string manipulation.

## Recursive Descent

### Find Values Anywhere in Structure

```bash
# Find all values for a key anywhere in nested structure
echo '{"user":{"name":"Alice","contact":{"email":"alice@example.com"}},"admin":{"email":"admin@example.com"}}' | jq '.. | .email? // empty'
# Output:
# "alice@example.com"
# "admin@example.com"

# Recursively find all objects with specific key
jq '.. | objects | select(has("error"))' data.json

# Get all numeric values
jq '.. | numbers' data.json

# Get all strings matching pattern
jq '.. | strings | select(test("@example\\.com"))' data.json
```

### Recursive Transformation

```bash
# Transform all objects at any level
jq 'walk(if type == "object" and has("id") then .id = (.id | tostring) else . end)' data.json

# Remove all null values recursively
jq 'walk(if type == "object" then with_entries(select(.value != null)) else . end)' data.json

# Recursively rename keys
jq 'walk(if type == "object" then with_entries(.key |= gsub("_"; "-")) else . end)' data.json
```

## Custom Functions

### Define Reusable Functions

```bash
# Simple function
echo '[1,2,3,4,5]' | jq 'def double: . * 2; map(double)'
# Output: [2,4,6,8,10]

# Function with parameters
jq 'def multiply(n): . * n; map(multiply(3))' numbers.json

# Multiple functions
jq 'def double: . * 2; def triple: . * 3; map(double) + map(triple)' numbers.json
```

### Recursive Functions

```bash
# Factorial
echo '5' | jq 'def factorial: if . <= 1 then 1 else . * ((. - 1) | factorial) end; factorial'
# Output: 120

# Fibonacci
echo '10' | jq 'def fib: if . <= 1 then . else ((. - 1) | fib) + ((. - 2) | fib) end; fib'

# Recursive tree traversal
jq 'def traverse: .value, (.children[]? | traverse); traverse' tree.json
```

### Composition

```bash
# Chain functions
jq 'def double: . * 2; def increment: . + 1; map(double | increment)' numbers.json

# Functions calling functions
jq 'def square: . * .; def sum_of_squares: map(square) | add; sum_of_squares' numbers.json
```

## Conditional Logic

### If-Then-Else

```bash
# Simple conditional
echo '{"age":20}' | jq 'if .age >= 18 then "adult" else "minor" end'
# Output: "adult"

# With field assignment
jq '.category = if .price > 100 then "premium" else "standard" end' products.json

# Multiple conditions
jq 'if .age < 13 then "child" elif .age < 18 then "teen" elif .age < 65 then "adult" else "senior" end' person.json
```

### Complex Conditionals

```bash
# Nested conditionals
jq 'if .user then (if .user.premium then "premium" else "basic" end) else "guest" end' session.json

# Multiple field conditions
jq 'if .status == "active" and .balance > 0 then "eligible" else "ineligible" end' account.json

# Conditional object construction
jq 'if .type == "premium" then {id, name, features: .premiumFeatures} else {id, name} end' user.json
```

## String Manipulation

### Interpolation and Formatting

```bash
# String interpolation
echo '{"name":"Alice","age":30}' | jq '"Hello, \(.name)! You are \(.age) years old."'
# Output: "Hello, Alice! You are 30 years old."

# Format numbers
echo '{"price":1234.5}' | jq '"Price: $\(.price)"'
# Output: "Price: $1234.5"

# Conditional interpolation
jq '"Status: \(if .active then "Active" else "Inactive" end)"' record.json
```

### Split and Join

```bash
# Split string into array
echo '"apple,banana,orange"' | jq 'split(",")'
# Output: ["apple","banana","orange"]

# Join array into string
echo '["apple","banana","orange"]' | jq 'join(", ")'
# Output: "apple, banana, orange"

# Split on multiple characters
echo '"path/to/file.txt"' | jq 'split("/")'
# Output: ["path","to","file.txt"]
```

### Regex Operations

```bash
# Test if string matches
echo '"Hello123"' | jq 'test("[0-9]+")'
# Output: true

# Extract matches
echo '"Price: $123.45"' | jq 'match("\\$([0-9.]+)") | .captures[0].string'
# Output: "123.45"

# Find all matches
echo '"Email: alice@example.com, bob@test.com"' | jq '[match("\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"; "g")] | map(.string)'
# Output: ["alice@example.com","bob@test.com"]
```

### Search and Replace

```bash
# Simple replacement
echo '"hello world"' | jq 'gsub("world"; "universe")'
# Output: "hello universe"

# Regex replacement
echo '"Price: $100"' | jq 'gsub("\\$[0-9]+"; "$REDACTED")'
# Output: "Price: $REDACTED"

# Case conversion
echo '"Hello World"' | jq 'ascii_downcase'
# Output: "hello world"

echo '"hello world"' | jq 'ascii_upcase'
# Output: "HELLO WORLD"
```

### String Operations

```bash
# Check if string starts with
echo '"hello world"' | jq 'startswith("hello")'
# Output: true

# Check if string ends with
echo '"file.json"' | jq 'endswith(".json")'
# Output: true

# Check if contains
echo '"hello world"' | jq 'contains("wor")'
# Output: true

# Get string length
echo '"hello"' | jq 'length'
# Output: 5

# Trim whitespace
echo '"  hello  "' | jq 'ltrimstr(" ") | rtrimstr(" ")'
# Output: "hello"
```

## Date and Time

```bash
# Current timestamp
jq 'now' <<< 'null'

# Convert timestamp to date string
echo '1640000000' | jq 'todate'
# Output: "2021-12-20T11:33:20Z"

# Parse date string
echo '"2021-12-20T11:33:20Z"' | jq 'fromdate'
# Output: 1640000000

# Format date
jq 'now | strftime("%Y-%m-%d %H:%M:%S")' <<< 'null'
```

## Type Conversions

```bash
# String to number
echo '"123"' | jq 'tonumber'
# Output: 123

# Number to string
echo '123' | jq 'tostring'
# Output: "123"

# To array (if not already)
echo '5' | jq '[.]'
# Output: [5]

# Check types
echo '{"a":1,"b":"2","c":true}' | jq 'to_entries | map({key, type: (.value | type)})'
# Output: [{"key":"a","type":"number"},{"key":"b","type":"string"},{"key":"c","type":"boolean"}]
```
