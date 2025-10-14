# Direct LOAD TEST

Running a CDC Setup and add INSERTS INTO DB with Direct Load Hint.


```bash
insert /*+APPEND*/ into regions (REGION_NAME) values ('TEST APPEND 1');
commit;
```

Have a look if record is visible in Topic regions. Yes, it should be visible if your setup is correct.

Please know what [Tom](https://asktom.oracle.com/ords/f?p=100:11:0::::p11_question_id:1211797200346279484) is telling about direct load inserts:

Insert /*+ APPEND */ - why it would be horrible for Oracle to make that the "default".

a) **it isn't necessarily faster in general**. It does a direct path load to disk - bypassing the buffer cache. There are many cases - especially with smaller sets - where the direct path load to disk would be far slower than a conventional path load into the cache.

b) **a direct path load always loads above the high water mark**, since it is formatting and writing blocks directly to disk - **it cannot reuse any existing space**. Think about this - if you direct pathed an insert of a 100 byte row that loaded say just two rows - and you did that 1,000 times, you would be using at least 1,000 blocks (never reuse any existing space) - each with two rows. Now, if you did that using a conventional path insert - you would get about 70/80 rows per block in an 8k block database. You would use about 15 blocks. Which would you prefer?

c) you cannot query a table after direct pathing into it until you commit.

d) **how many people can direct path into a table at the same time? One - one and only one**. It would cause all modifications to serialize. No one else could insert/update/delete or merge into this table until the transaction that direct paths commits.

Direct path inserts should be used with care, in the proper circumstances. **A large load - direct path**. But most of the time - conventional path.