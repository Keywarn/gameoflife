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

## Parallisation (Master-Slave)

1. Read in image (setup)
2. Do processing for $n$ rounds (loop)
3. Output image (end)

#### INSERT IMAGE OF DESCRIPTION

As expected, the time for setup & end doesn't change as the number of rounds increases; it stays as:

* Setup: ~$10$ms
* End: ~$16$ms

These times are included as their effect is marginal.

### 1 iteration:

|         | 1  | 2  | 3  | 4  | 5  | avg|
|---------|----|----|----|----|----|----|
|time $ms$|$26$|$27$|$27$|$27$|$26$|$27$|

### 10 iterations:

|         | 1  | 2  | 3  | 4  | 5  | avg|
|---------|----|----|----|----|----|----|
|time $ms$|$26$|$26$|$27$|$28$|$26$|$27$|

### 100 iterations:

|         | 1  | 2  | 3  | 4  | 5  | avg|
|---------|----|----|----|----|----|----|
|time $ms$|$42$|$42$|$42$|$42$|$42$|$42$|

### 1000 iterations:

|         | 1   | 2   | 3   | 4   | 5   |  avg|
|---------|-----|-----|-----|-----|-----|-----|
|time $ms$|$175$|$175$|$175$|$175$|$175$|$175$|

### 10000 iterations:

|         | 1    | 2    | 3    | 4    | 5    |   avg|
|---------|------|------|------|------|------|------|
|time $ms$|$1517$|$1515$|$1516$|$1513$|$1516$|$1515$|

## Parallisation ()

