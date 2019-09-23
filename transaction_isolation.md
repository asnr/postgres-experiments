# Read Committed

The default transaction isolation level.

According to the documentation, the following phenomena are possible:

- nonrepeatable reads,
- phantom reads and
- serialisation anomalies.

## Nonrepeatable reads

Setup:

```sql
CREATE TABLE angsts (
  name TEXT,
  severity INTEGER
);

INSERT INTO angsts (name, severity) VALUES ('FOMO', 5);
```

In one long-lived transaction read the same value twice. In between the two reads, run a short-lived transaction that updates the value being read.

Long-lived client:

```sql
BEGIN;

SELECT severity FROM angsts WHERE name = 'FOMO';

-- Pause here while running the second client

SELECT severity FROM angsts WHERE name = 'FOMO';

COMMIT;
```

Short-lived client:

```sql
UPDATE angsts SET severity = 10 WHERE name = 'FOMO';
```

But now if we change the isolation level to `repeatable read`, this doesn't happen anymore:

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT severity FROM angsts WHERE name = 'FOMO';

-- Pause here while running the second client

SELECT severity FROM angsts WHERE name = 'FOMO';

COMMIT;
```


## PHANTOM READS

A long-lived transaction runs the same query twice and gets back different sets of rows.

```sql
BEGIN;

SELECT * FROM angsts WHERE severity = 5;

-- Pause here while running the second client

SELECT * FROM angsts WHERE severity = 5;

COMMIT;
```

```sql
INSERT INTO angsts (name, severity) VALUES ('Existential dread', 5);
```

The first `SELECT` statement returns one row, the second two rows.

Now if we change the isolation level to `repeatable read`, this doesn't happen anymore:

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT * FROM angsts WHERE severity = 5;

-- Pause here while running the second client

SELECT * FROM angsts WHERE severity = 5;

COMMIT;
```
