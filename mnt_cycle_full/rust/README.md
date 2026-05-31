# Rust reference layer

`mnt_cycle_full` uses arkworks as the source of truth for the two curves:

- `ark-mnt4-753` for MNT4-753 reference pairing;
- `ark-mnt6-753` for MNT6-753 reference pairing.

The tests check the defining field-cycle equalities:

```text
Fr(MNT4-753) = Fq(MNT6-753)
Fr(MNT6-753) = Fq(MNT4-753)
```

The binary `mnt_cycle_full_report` prints the reference pairing digests and the relation-fragment accounting table.
