# Table locks

Let's simulate an outage I've had to deal with in the past.

* Simulate an AUTOVACUUM by taking a `SHARE UPDATE EXCLUSIVE` lock,
* then add a column to a table with an ALTER TABLE command, which requests an `ACCESS EXCLUSIVE` lock on the table, and finally
* issue SELECT commands to simulate normal application activity.

We will see that the SELECT commands hang, even though the lock mode they request, `ACCESS SHARE`, can run concurrently with the lock mode used by AUTOVACUUM, `SHARE UPDATE EXCLUSIVE`.


```sql
CREATE TABLE breads (
  name TEXT,
  price INTEGER
);

INSERT INTO breads (name, price) VALUES ('baguette', 3);
```

Then simulate a long-running auto-vacuum with

```sql
BEGIN;

LOCK TABLE breads IN SHARE UPDATE EXCLUSIVE MODE;

SELECT pg_sleep(3600);

COMMIT;
```

In a second terminal

```sql
ALTER TABLE breads ADD COLUMN shelf_life integer;
```

This will hang :(

Then in a third terminal, let's try and simulate normal operations by selecting some rows in the `breads` table:

```sql
SELECT * FROM breads;
```

This will also hang.

From an operations perspective, when a table gets locked like this in production, you'll likely find out when you get paged due to requests timing out or users complaining. In such a situation, you can relatively quickly determine if lock contention is the problem by querying the `pg_locks` table:

```
# select
    lock.locktype, lock.relation, class.relname, lock.pid, lock.mode, lock.granted
  from pg_locks lock left join pg_class class on lock.relation = class.oid
  where not lock.granted;

 locktype | relation | relname | pid |        mode         | granted
----------|----------|---------|-----|---------------------|---------
 relation |    24583 | breads  |  58 | AccessExclusiveLock | f
 relation |    24583 | breads  |  73 | AccessShareLock     | f
(2 rows)
```

Joining onto the `pg_stat_activity` table can also show us which queries are stuck:

```
# select
    lock.locktype, lock.relation, class.relname, lock.pid, lock.mode, lock.granted, act.query
  from pg_locks lock left join pg_class class on lock.relation = class.oid
    left join pg_stat_activity act on lock.pid = act.pid
  where not lock.granted;

 locktype | relation | relname | pid |        mode         | granted |                       query
----------|----------|---------|-----|---------------------|---------|---------------------------------------------------
 relation |    24583 | breads  |  58 | AccessExclusiveLock | f       | ALTER TABLE breads ADD COLUMN shelf_life integer;
 relation |    24583 | breads  |  73 | AccessShareLock     | f       | SELECT * FROM breads;
(2 rows)

```

From there we can find the query that is holding onto the lock under contention, narrowing our search to locks on affected table, `relname = 'breads'`:

```
# select
    lock.locktype, lock.relation, class.relname, lock.pid, lock.mode, lock.granted, now() - act.query_start as runtime, act.query
  from pg_locks lock left join pg_class class on lock.relation = class.oid
    left join pg_stat_activity act on lock.pid = act.pid
  where lock.granted and class.relname = 'breads';

 locktype | relation | relname | pid |           mode           | granted |     runtime     |         query
----------|----------|---------|-----|--------------------------|---------|-----------------|------------------------
 relation |    24583 | breads  |  45 | ShareUpdateExclusiveLock | t       | 00:17:35.516095 | SELECT pg_sleep(3600);
(1 row)
```
