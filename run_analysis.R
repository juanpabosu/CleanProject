##Load packages.


packages <- c("data.table", "reshape2")
sapply(packages, require, character.only=TRUE, quietly=TRUE)


##Set path.

path <- getwd()


##Get the data & Download the file. 


url <- "https://d396qusza40orc.cloudfront.net/getdata%2Fprojectfiles%2FUCI%20HAR%20Dataset.zip"
f <- "CleanData.zip"
if (!file.exists(path)) {dir.create(path)}
download.file(url, file.path(path, f))


##Unzip the file with WinRar on Windows


exe <- file.path("C:", "Program Files (x86)", "WinRAR", "WinRAR.exe")
parameters <- "x"
cmd <- paste(paste0("\"", exe, "\""), parameters, paste0("\"", file.path(path,f), "\""))
system(cmd)


##The files are in a folder named UCI HAR Dataset. Set this folder as the input path. 


inputpath <- file.path(path, "UCI HAR Dataset")

##Read files


##Read the subject files.


dtSubjTrain <- fread(file.path(inputpath, "train", "subject_train.txt"))
dtSubjTest <- fread(file.path(inputpath, "test" , "subject_test.txt" ))


##Read the activity files.


dtActTrain <- fread(file.path(inputpath, "train", "Y_train.txt"))
dtActTest <- fread(file.path(inputpath, "test" , "Y_test.txt" ))


##Read the data files using a data table function convertion

fileToDataTable <- function (f) {
df <- read.table(f)
dt <- data.table(df)
}
dtTrain <- fileToDataTable(file.path(inputpath, "train", "X_train.txt"))
dtTest <- fileToDataTable(file.path(inputpath, "test" , "X_test.txt" ))



##Merge the training and the test sets


##Concatenate the data tables.


dtSubject <- rbind(dtSubjTrain, dtSubjTest)
setnames(dtSubject, "V1", "subject")
dtActivity <- rbind(dtActTrain, dtActTest)
setnames(dtActivity, "V1", "activityNum")
dt <- rbind(dtTrain, dtTest)


##Merge columns.

dtSubject <- cbind(dtSubject, dtActivity)
dt <- cbind(dtSubject, dt)


##Set key.


setkey(dt, subject, activityNum)



##Mean and standard deviation


##Features.txt file tells which variables in dt are measurements for the mean and standard deviation.

dtFeatures <- fread(file.path(inputpath, "features.txt"))
setnames(dtFeatures, names(dtFeatures), c("featureNum", "featureName"))


##Subset only measurements for the mean and standard deviation.


dtFeatures <- dtFeatures[grepl("mean\\(\\)|std\\(\\)", featureName)]


##Convert the column numbers to a vector of variable names matching columns in dt.


dtFeatures$featureCode <- dtFeatures[, paste0("V", featureNum)]


##Subset these variables using variable names.


select <- c(key(dt), dtFeatures$featureCode)
dt <- dt[, select, with=FALSE]



##Use descriptive activity names


##activity_labels.txt will be used to add descriptive names to the activities.


dtActivityNames <- fread(file.path(inputpath, "activity_labels.txt"))
setnames(dtActivityNames, names(dtActivityNames), c("activityNum", "activityName"))



##Label with descriptive activity names


##Merge activity labels.


dt <- merge(dt, dtActivityNames, by="activityNum", all.x=TRUE)


##Add activityName as a key.


setkey(dt, subject, activityNum, activityName)


##Melt the data table to reshape it from a short and wide format to a tall and narrow format.


dt <- data.table(melt(dt, key(dt), variable.name="featureCode"))


##Merge activity name.


dt <- merge(dt, dtFeatures[, list(featureNum, featureCode, featureName)], by="featureCode", all.x=TRUE)


##Create a new variable, `activity` that is equivalent to `activityName` as a factor class.
##Create a new variable, `feature` that is equivalent to `featureName` as a factor class.


dt$activity <- factor(dt$activityName)
dt$feature <- factor(dt$featureName)


##Seperate features from `featureName` using the helper function `grepthis`.


grepthis <- function (regex) {
  grepl(regex, dt$feature)
}

## Features with 2 categories
n <- 2
y <- matrix(seq(1, n), nrow=n)
x <- matrix(c(grepthis("^t"), grepthis("^f")), ncol=nrow(y))
dt$featDomain <- factor(x %*% y, labels=c("Time", "Freq"))
x <- matrix(c(grepthis("Acc"), grepthis("Gyro")), ncol=nrow(y))
dt$featInstrument <- factor(x %*% y, labels=c("Accelerometer", "Gyroscope"))
x <- matrix(c(grepthis("BodyAcc"), grepthis("GravityAcc")), ncol=nrow(y))
dt$featAcceleration <- factor(x %*% y, labels=c(NA, "Body", "Gravity"))
x <- matrix(c(grepthis("mean()"), grepthis("std()")), ncol=nrow(y))
dt$featVariable <- factor(x %*% y, labels=c("Mean", "SD"))

## Features with 1 category
dt$featJerk <- factor(grepthis("Jerk"), labels=c(NA, "Jerk"))
dt$featMagnitude <- factor(grepthis("Mag"), labels=c(NA, "Magnitude"))

## Features with 3 categories
n <- 3
y <- matrix(seq(1, n), nrow=n)
x <- matrix(c(grepthis("-X"), grepthis("-Y"), grepthis("-Z")), ncol=nrow(y))
dt$featAxis <- factor(x %*% y, labels=c(NA, "X", "Y", "Z"))


##Check to make sure all possible combinations of `feature` are accounted for by all possible combinations of the factor class variables.


r1 <- nrow(dt[, .N, by=c("feature")])
r2 <- nrow(dt[, .N, by=c("featDomain", "featAcceleration", "featInstrument", "featJerk", "featMagnitude", "featVariable", "featAxis")])
r1 == r2


##Create a tidy data set with the average of each variable for each activity and each subject.


setkey(dt, subject, activity, featDomain, featAcceleration, featInstrument, featJerk, featMagnitude, featVariable, featAxis)
dtTidy <- dt[, list(count = .N, average = mean(value)), by=key(dt)]


##Save to file


##Save data table objects to an txt file called `HumanActivityRecognitionUsingSmartphones.txt`.


f <- file.path(path, "HumanActivityRecognitionUsingSmartphones.txt")
write.table(dtTidy, f, quote=FALSE, sep="\t", row.names=FALSE)
