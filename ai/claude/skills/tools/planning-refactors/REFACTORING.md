# Refactoring Patterns

Systematic approaches for planning and executing code refactors.

## Deprecated API Migration

### Finding All Usage

```bash
# Find all method calls on deprecated API
ast-grep -p 'oldApi.$METHOD($$$)' --lang ts

# Find property access
ast-grep -p 'oldApi.$PROP' --lang ts

# Find imports
ast-grep -p 'import { $$$, oldApi, $$$ } from "$MODULE"' --lang ts
ast-grep -p 'import oldApi from "$MODULE"' --lang ts

# Find re-exports
ast-grep -p 'export { oldApi } from "$MODULE"' --lang ts
```

### Migration Strategy

```markdown
## API Migration Template

**Old API**: `oldApi`
**New API**: `newApi`

**Breaking Changes**:
- `oldApi.get(callback)` → `newApi.get().then(callback)`
- `oldApi.sync()` → `await newApi.async()`

**Import Changes**:
- FROM: `import { oldApi } from 'legacy'`
- TO: `import { newApi } from 'modern'`

**Compatibility**:
- Keep oldApi in tests for backward compatibility
- Add adapter layer if needed
```

### Execution Order

1. Update import statements
2. Update simple method calls (1:1 replacements)
3. Update complex calls (callbacks → promises)
4. Update error handling
5. Update tests
6. Remove old imports

## React Class to Hooks

### Find All Class Components

```bash
# Class components
ast-grep -p 'class $NAME extends Component { $$$ }' --lang tsx
ast-grep -p 'class $NAME extends React.Component { $$$ }' --lang tsx
ast-grep -p 'class $NAME extends PureComponent { $$$ }' --lang tsx

# With TypeScript types
ast-grep -p 'class $NAME extends Component<$PROPS> { $$$ }' --lang tsx
ast-grep -p 'class $NAME extends Component<$PROPS, $STATE> { $$$ }' --lang tsx
```

### Find Lifecycle Methods

```bash
# Mount/unmount
ast-grep -p 'componentDidMount() { $$$ }' --lang tsx
ast-grep -p 'componentWillUnmount() { $$$ }' --lang tsx

# Update
ast-grep -p 'componentDidUpdate($PREV_PROPS, $PREV_STATE) { $$$ }' --lang tsx
ast-grep -p 'shouldComponentUpdate($$$) { $$$ }' --lang tsx

# Error boundaries
ast-grep -p 'componentDidCatch($ERROR, $INFO) { $$$ }' --lang tsx
```

### Find State Usage

```bash
# State access
ast-grep -p 'this.state.$PROP' --lang tsx

# setState calls
ast-grep -p 'this.setState($$$)' --lang tsx
ast-grep -p 'this.setState({ $$$PROPS })'  --lang tsx
ast-grep -p 'this.setState(($PREV) => $$$)' --lang tsx

# Props access
ast-grep -p 'this.props.$PROP' --lang tsx
```

### Migration Mapping

| Class Pattern | Hooks Equivalent |
|--------------|------------------|
| `this.state.count` | `count` (from useState) |
| `this.setState({count: 5})` | `setCount(5)` |
| `componentDidMount() { fetch() }` | `useEffect(() => { fetch() }, [])` |
| `componentWillUnmount() { cleanup() }` | `useEffect(() => { return cleanup }, [])` |
| `componentDidUpdate(prev) { if (prev.id !== this.props.id) }` | `useEffect(() => {}, [id])` |

## Type Migration

### TypeScript Any to Specific Types

```bash
# Find any types
ast-grep -p ': any' --lang ts

# In function parameters
ast-grep -p 'function $NAME($PARAM: any) { $$$ }' --lang ts

# In variable declarations
ast-grep -p 'const $VAR: any = $VALUE' --lang ts

# In type definitions
ast-grep -p 'type $NAME = any' --lang ts
```

### Prop Types to TypeScript

```bash
# Find PropTypes usage
ast-grep -p '$NAME.propTypes = { $$$ }' --lang tsx

# Find defaultProps
ast-grep -p '$NAME.defaultProps = { $$$ }' --lang tsx

# Convert to interface:
# PropTypes.string → string
# PropTypes.number → number
# PropTypes.bool → boolean
# PropTypes.array → Array<T>
# PropTypes.object → Record<string, unknown>
```

## Code Modernization

### Var to Const/Let

```bash
# Find all var declarations
ast-grep -p 'var $VAR = $VALUE' --lang js

# Analysis:
# - Never reassigned? → const
# - Reassigned? → let
# - Block scoped already? → const/let
```

### Function Declarations to Arrow Functions

```bash
# Find function expressions
ast-grep -p 'const $NAME = function($$$) { $$$ }' --lang js

# Find function declarations in objects
ast-grep -p '$OBJ = { $METHOD: function($$$) { $$$ } }' --lang js

# Convert to:
# const name = (params) => { body }
```

### Callbacks to Async/Await

```bash
# Find callback patterns
ast-grep -p '$FUNC($$$, ($ERR, $DATA) => { $$$ })' --lang js

# Find promise chains
ast-grep -p '$PROMISE.then($$$).then($$$)' --lang js

# Convert to async/await
```

## API Pattern Changes

### REST to GraphQL

```bash
# Find fetch calls
ast-grep -p 'fetch(`/api/$ENDPOINT`, $$$)' --lang ts

# Find axios calls
ast-grep -p 'axios.get(`/$PATH`)' --lang ts

# Map to GraphQL queries
```

### Event Emitter to Observable

```bash
# Find event emitter usage
ast-grep -p '$EMITTER.on("$EVENT", $CALLBACK)' --lang ts
ast-grep -p '$EMITTER.emit("$EVENT", $$$)' --lang ts

# Convert to Observable pattern
```

## Systematic Refactoring Process

### Phase 1: Discovery

```bash
# Find all occurrences
ast-grep -p '<old-pattern>' --json > occurrences.json

# Analyze distribution
jq 'group_by(.file) | map({file: .[0].file, count: length})' occurrences.json

# Identify high-impact files (most occurrences)
jq 'group_by(.file) | map({file: .[0].file, count: length}) | sort_by(-.count) | .[0:10]' occurrences.json
```

### Phase 2: Categorization

Group matches by complexity:

**Simple** (direct 1:1 replacement):
```bash
# Example: Method rename
oldApi.getData() → newApi.getData()
```

**Moderate** (signature change):
```bash
# Example: Callback to promise
oldApi.get(url, callback) → newApi.get(url).then(callback)
```

**Complex** (logic change):
```bash
# Example: Sync to async
const data = oldApi.getSync()
→
const data = await newApi.getAsync()
```

### Phase 3: Execution

1. **Start with simple replacements**
   - Low risk
   - Build confidence
   - Quick wins

2. **Move to moderate changes**
   - Review each change
   - Test incrementally
   - Commit often

3. **Tackle complex changes last**
   - One at a time
   - Thorough testing
   - Document decisions

### Phase 4: Verification

```bash
# Confirm no old pattern remains
ast-grep -p '<old-pattern>' --lang <lang>
# Should return no matches

# Check for new pattern
ast-grep -p '<new-pattern>' --lang <lang>
# Should match expected count

# Verify imports updated
ast-grep -p 'import { $$$, oldApi, $$$ }' --lang ts
# Should return no matches
```

## Rollback Strategy

Before starting:

```bash
# Create feature branch
git checkout -b refactor/api-migration

# Commit baseline
git commit -m "Pre-refactor baseline"
```

During refactoring:

```bash
# Commit after each phase
git commit -m "Phase 1: Simple replacements complete"

# If something breaks
git revert HEAD  # Undo last commit
git reset --hard <commit>  # Reset to baseline
```

## Common Pitfalls

### Over-Automation

**Problem**: Replacing all occurrences blindly

**Solution**: Review context for each match
- Comments might mention old API
- Tests might intentionally use old API
- Documentation might reference old patterns

### Missing Edge Cases

**Problem**: Not finding all variations

**Solution**: Search multiple patterns
```bash
# Not just:
ast-grep -p 'oldApi.get($$$)'

# Also check:
ast-grep -p 'const $VAR = oldApi'
ast-grep -p 'oldApi["get"]($$$)'  # Bracket notation
ast-grep -p '{ api: oldApi }'     # Object properties
```

### Breaking Tests

**Problem**: Tests fail after refactor

**Solution**: Update tests first or in parallel
- Test files might use old patterns
- Test mocks might need updating
- Test fixtures might reference old API

### Import Chaos

**Problem**: Unused imports, missing imports

**Solution**: Update imports systematically
```bash
# Remove old imports
# Add new imports
# Run linter to clean up unused
```
