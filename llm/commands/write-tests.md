## Step 1: Determine scope
If arguments were provided (`$ARGUMENTS` is not empty):
- Target only the file or directory specified: `$ARGUMENTS`

If no arguments were provided:
- Scan the entire codebase
- Identify all source files, excluding: node_modules, dist, build, .git, 
  vendor, and any directories that contain only test files
- Process each file that has missing or no test coverage

## Step 2: Detect the environment
Inspect the project once (regardless of scope) to determine:
- Testing framework in use (check package.json, pyproject.toml, requirements.txt,
  jest.config.*, vitest.config.*, pytest.ini, etc.)
- Existing test file conventions (naming pattern, location, import style)
- Mocking libraries available (jest.mock, sinon, unittest.mock, vi.mock, etc.)
- Read a sample of existing tests to internalize style and patterns

## Step 3: Analyze target file(s)
For each file in scope:
- Identify all exported functions, classes, and methods
- Cross-reference any existing test file to find what's already covered
- Flag edge cases, error paths, and boundary conditions not yet tested
- Note dependencies that will need to be mocked

## Step 4: Write the missing tests
- Match the exact style, structure, and naming conventions of existing tests
- If no existing tests exist, choose the style that best fits the detected framework
- Cover: happy paths, edge cases, error handling, and boundary conditions
- Use descriptive test names that explain expected behavior, not implementation
- Mock external dependencies (APIs, DB calls, file I/O) — do not make real calls
- Do not delete or modify any existing tests

## Step 5: Output
For each file processed:
- If a test file already exists: show only the new test blocks to add, with a 
  comment indicating where they should be inserted
- If no test file exists: create the full test file with proper imports and structure

When all files are processed, provide a summary:
- How many files were analyzed
- How many had missing coverage
- What categories of gaps were most common (error handling, edge cases, etc.)
