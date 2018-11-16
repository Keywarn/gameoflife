# Experiments

---

## Without parallisation

1. Read in image
2. Do processing for $n$ rounds
3. Output image

### 1 iteration:

|         | 1  | 2  | 3  | 4  | 5  | avg|
|---------|----|----|----|----|----|----|
|time $ms$|$60$|$57$|$58$|$54$|$57$|$57$|

### 5 iterations:

|         | 1  | 2  | 3  | 4  | 5  | avg|
|---------|----|----|----|----|----|----|
|time $ms$|$60$|$57$|$53$|$58$|$57$|$57$|

### 100 iterations:

|         | 1   | 2   | 3   | 4   | 5   | avg |
|---------|-----|-----|-----|-----|-----|-----|
|time $ms$|$109$|$110$|$106$|$107$|$109$|$108$|

### 1000 iterations

|         | 1   | 2   | 3   | 4   | 5   | avg |
|---------|-----|-----|-----|-----|-----|-----|
|time $ms$|$599$|$599$|$598$|$595$|$596$|$597$|

### Conclusion

The IO likely takes up the most time (~$55ms$) when there's only 1 iteration.

INSERT LAGRANGE THING

### Notes

We noticed that printing takes up a lot of time so we removed any print statements in our for loop.

---

## Parallisation