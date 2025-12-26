def build_sql(tableName: str, columnsDefinition: list) -> dict:
    """Build SQL query string using provided column definitions.
    
    Args:
        tableName: Name of the table to create
        columnsDefinition: List of column definition strings (e.g., ["id INT PRIMARY KEY", "name VARCHAR(50)"])
    
    Returns:
        Dictionary with 'sql' key containing the CREATE TABLE statement
        
    Example:
        >>> result = build_sql("users", ["id INT PRIMARY KEY", "name VARCHAR(50)", "email VARCHAR(100)"])
        >>> print(result['sql'])
        CREATE TABLE users( id INT PRIMARY KEY, name VARCHAR(50), email VARCHAR(100));
    """
    # Validate input types
    if not isinstance(tableName, str) or \
       not all(isinstance(col, str) for col in columnsDefinition):
        raise TypeError("Invalid Arguments")
    
    # Build the CREATE TABLE statement
    query = "CREATE TABLE {0}(".format(tableName)
    
    # Join column definitions with commas
    # Each column definition is already a complete string (e.g., "id INT PRIMARY KEY")
    defs = ", ".join(columnsDefinition)
    query += defs + ");"
    
    # Return as dictionary object
    # Note: CREATE TABLE doesn't typically use parameterized queries,
    # but we return an empty params list for consistency with the docstring comment
    return {'sql': query, 'params': []}

