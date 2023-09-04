USE housingdata;
SELECT *
FROM nashvillehousingdatafordatacleaning;

-- Stanardizing the date format:
-- Adding a new column for updated date
ALTER TABLE nashvillehousingdatafordatacleaning
Add Sale_DateConverted DATE;

-- converting to standard date format and adding to new column:
UPDATE nashvillehousingdatafordatacleaning
SET Sale_DateConverted = CONVERT(SaleDate, DATE);

SELECT SaleDate,Sale_DateConverted 
FROM nashvillehousingdatafordatacleaning;
-- -----------------------------------------------------------------------------------
-- Now we will populate the property address data where there are blank entries:
SELECT *
FROM nashvillehousingdatafordatacleaning
-- WHERE PropertyAddress IS NULL;
ORDER BY ParcelID;

-- note: On inspecting the table it was found that some parcel entries had the same parcel ids and addresses
-- but for some of these entires the address was missing. So we had to update these null values.
-- The self join query below finds these rows.

-- PERFORMING SELF JOIN:
SELECT ns1.ParcelID, ns1.PropertyAddress, ns2.ParcelID
FROM nashvillehousingdatafordatacleaning ns1
JOIN nashvillehousingdatafordatacleaning ns2
	ON ns1.parcelID = ns2.parcelID
    AND ns1.UniqueID <> ns2.UniqueID
WHERE ns1.PropertyAddress IS NULL;


-- Updating the null values for the property addresses:
-- Query explanation
-- The first JOIN clause joins the table "ns1" with a subquery aliased as "ns2." 
-- The subquery retrieves distinct "ParcelID" and "PropertyAddress" pairs from rows where the "PropertyAddress" is not NULL. 
-- This subquery acts as a lookup table to find valid addresses for the rows that have missing addresses.

UPDATE nashvillehousingdatafordatacleaning AS ns1
JOIN (
    SELECT DISTINCT ParcelID, PropertyAddress
    FROM nashvillehousingdatafordatacleaning
    WHERE PropertyAddress IS NOT NULL
) AS ns2
ON ns1.ParcelID = ns2.ParcelID
SET ns1.PropertyAddress = ns2.PropertyAddress
WHERE ns1.PropertyAddress IS NULL;

-- ( the self join query can be ran again for confirmation and it will displauy table with no entries
-- 		this confrims that all missing addresses have been filled.)


-- Breaking out address into individual columns (Address, ity,State)

SELECT PropertyAddress
FROM nashvillehousingdatafordatacleaning;

SELECT 
-- The function below returns a substring of a string before a specified number (a comma in this case) of delimiter occurs:
SUBSTRING_INDEX(PropertyAddress, ",", 1) AS ADDRESS,
SUBSTRING_INDEX(PropertyAddress, ',', -1) AS ADDRESS -- selects the substring after the comma
FROM nashvillehousingdatafordatacleaning;

-- Adding two new columns for storing the seperated property address
-- in terms of locality and city:

ALTER TABLE nashvillehousingdatafordatacleaning
Add PropertySplitAddress VARCHAR(255);

UPDATE nashvillehousingdatafordatacleaning
SET PropertySplitAddress = SUBSTRING_INDEX(PropertyAddress, ",", 1);

ALTER TABLE nashvillehousingdatafordatacleaning
Add PropertySplitAddressCity VARCHAR(255);


UPDATE nashvillehousingdatafordatacleaning
SET PropertySplitAddressCity = SUBSTRING_INDEX(PropertyAddress, ',', -1);

SELECT *
FROM nashvillehousingdatafordatacleaning;
-- ---------------------------------------------------------------------------------
-- Doing the same with owner address:
SELECT OwnerAddress
FROM nashvillehousingdatafordatacleaning;

-- checking the query to be used:
SELECT 
SUBSTRING_INDEX(OwnerAddress, ",", 1) AS ADDRESS1, -- selects everything before the first comma as specified by '1'
SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2),',',-1) AS ADDRESS2,
-- the above query first selects everything before the second comma ('2') i.e 
-- '1808 FOX CHASE DR, GOODLETTSVILLE' and then the outer substirng_index 
-- selects everything after the last comma ('-1') i.e GOODLETTSVILLE from '1808 FOX CHASE DR, GOODLETTSVILLE'
SUBSTRING_INDEX(OwnerAddress, ',', -1) AS ADDRESS3,OwnerAddress -- thia aelects everyhting after the last comma ('-1') i.e 'TN'
FROM nashvillehousingdatafordatacleaning;

-- now adding new colums to the tbale to store the owner address as three  seperate strings:
ALTER TABLE nashvillehousingdatafordatacleaning
Add OwnerSplitAddress VARCHAR(255);
UPDATE nashvillehousingdatafordatacleaning
SET OwnerSplitAddress = SUBSTRING_INDEX(OwnerAddress, ",", 1);

ALTER TABLE nashvillehousingdatafordatacleaning
Add OwnerSplitCity VARCHAR(255);
UPDATE nashvillehousingdatafordatacleaning
SET OwnerSplitCity = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2),',',-1);

ALTER TABLE nashvillehousingdatafordatacleaning
Add OwnerSplitState VARCHAR(255);
UPDATE nashvillehousingdatafordatacleaning
SET OwnerSplitState = SUBSTRING_INDEX(OwnerAddress, ',', -1);

SELECT *
FROM nashvillehousingdatafordatacleaning;



-- -------------------------------------------------------------------------
-- Changing Y and N to Yes and No in 'Sold as Vacant' Field:

-- COunting 'No' and 'Yes' in Sold AsVacant column to see any
-- other incorrect entries like 'Y' and 'N' appear up:
SELECT SoldAsVacant, COUNT(SoldAsVacant)
FROM nashvillehousingdatafordatacleaning
GROUP BY SoldAsVacant
ORDER BY COUNT(SoldAsVacant);

SELECT SoldAsVacant
, CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N'THEN 'No'
		ELSE SoldAsVacant
        END
FROM nashvillehousingdatafordatacleaning;
-- Case statment sare just like if else statments:

-- CASE
--     WHEN condition1 THEN result1
--     WHEN condition2 THEN result2
--     WHEN conditionN THEN resultN
--     ELSE result
-- END;

-- now using the same case statment as above to update the SoldAsVacant column:
UPDATE nashvillehousingdatafordatacleaning
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N'THEN 'No'
		ELSE SoldAsVacant
        END;
        
        
-- -------------------------------------
-- Remove dupicates:

-- Heee we will use the row_number window function (new concept) along with partition by

-- Random queries in the middle: (useless and just for testing stuff)
-- SELECT row_number() OVER (ORDER BY SalePrice) row_num,UniqueID,SalePrice
-- FROM nashvillehousingdatafordatacleaning;

-- SELECT *, ROW_NUMBER() OVER (Partition by ParcelID,
-- 				PropertyAddress ORDER BY UniqueID) row_num
-- FROM nashvillehousingdatafordatacleaning;
-- --------------------------------------------- emd of random queries

-- Underlying logic:----------------- ( VERY IMPORTANT!)
-- What we are assuming here is that if some rows have the same 
-- parcel id, property address, sale price, sale date and legal reference 
-- then basically they are just duplicates.
-- so we will partition our original table based on these factors (partitioning is done to display all the entries unlike group by)
-- also note that other factors in the original table wouldn;t be considered
-- this means that if two rows have the same parcel id, property address and so on despite having other different column entries
-- so these two rows will be classified as duplicates being listed as 1,2 or 1,2,3. 
-- All the rows classified as 2 nd so on will be our duplicates
-- then we will use the row_number window function to seperate these partitions 
-- --------------- end of underlying logic


-- creatig a CTE to simplify things and to be used later. The CTE is based on the logic stated above.
WITH RowNumCTE AS(
SELECT *,
ROW_NUMBER() OVER (
Partition by ParcelID,
				PropertyAddress,
				SalePrice,
				SaleDate,LegalReference
                ORDER BY UniqueID) row_num
FROM nashvillehousingdatafordatacleaning
)
DELETE
FROM RowNumCTE
WHERE row_num>1;

-- note: CTE can only be run with the query right below it. So the SELECT query right below the
-- CTE will modified to delete query to delete the duplicate rows after finding them.
-- Again the DELETE will chnaged to SELECT in the same query to see if duplicates still remain.
-- The delete query is also seperately written down below just for reference.

-- We are checking the number of duplicate entries in the row above. If no rows are dsiplayed so there are no duplicate entries

-- Deleting the duplicate entries:
DELETE
FROM RowNumCTE
WHERE row_num>1;

CREATE TABLE nashvillehousing_backup AS
SELECT * FROM nashvillehousingdatafordatacleaning;

SELECT *
FROM nashvillehousing_backup;

-- counting the total number of entries:
SELECT COUNT(*) AS total_entries
FROM nashvillehousing_backup;
SELECT COUNT(*) AS total_entries
FROM nashvillehousingdatafordatacleaning;

DELETE FROM nashvillehousing_backup
WHERE (ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference, UniqueID) IN (
    SELECT ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference, UniqueID
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
                                 ORDER BY UniqueID) AS row_num
        FROM nashvillehousing_backup
    ) AS RowNumCTE
    WHERE row_num > 1
);

-- Again counting entries in both the tables to see if duplicate rows were deleted from the backup able:
SELECT COUNT(*) AS total_entries
FROM nashvillehousing_backup;

SELECT COUNT(*) AS total_entries
FROM nashvillehousingdatafordatacleaning;

-- Results:
-- On running the CTE above it was found that there were 104 duplicate rows.
-- After running the deete query and counting it was found that now the backup table has 104 less entries than the original one
-- this means the delete works fine. 



-- ( Will try to understand this too)
-- DELETE n
-- FROM nashvillehousing_backup n
-- LEFT JOIN (
--     SELECT *,
--            ROW_NUMBER() OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
--                              ORDER BY UniqueID) AS row_num
--     FROM nashvillehousing_backup
-- ) AS RowNumCTE ON n.ParcelID = RowNumCTE.ParcelID
--               AND n.PropertyAddress = RowNumCTE.PropertyAddress
--               AND n.SalePrice = RowNumCTE.SalePrice
--               AND n.SaleDate = RowNumCTE.SaleDate
--               AND n.LegalReference = RowNumCTE.LegalReference
--               AND n.UniqueID = RowNumCTE.UniqueID
-- WHERE RowNumCTE.row_num > 1;
-- --------------------------------------------------------------------------------


-- Unfortunatley Mysql doesnt allow to directly update or delete in CTEs 
-- so we will be using the CTE as a subquery in the query below to delete from original table instead.


-- Testing:
-- SELECT ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference, MIN(UniqueID) AS min_unique_id
-- FROM nashvillehousingdatafordatacleaning
-- HAVING COUNT(*) > 1
-- GROUP BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference;

CREATE TABLE nashvillehousing_backup_2 AS
SELECT * FROM nashvillehousingdatafordatacleaning;

SELECT COUNT(*) AS total_entries
FROM nashvillehousing_backup_2;

-- I understand this delete query better. ( VERY EASY TO UNDERSTAND)----------------------------------------------------
DELETE n
FROM nashvillehousing_backup_2 n
LEFT JOIN (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
                             ORDER BY UniqueID) AS row_num
    FROM nashvillehousing_backup_2
) AS RowNumCTE ON n.ParcelID = RowNumCTE.ParcelID
              AND n.PropertyAddress = RowNumCTE.PropertyAddress
              AND n.SalePrice = RowNumCTE.SalePrice
              AND n.SaleDate = RowNumCTE.SaleDate
              AND n.LegalReference = RowNumCTE.LegalReference
              AND n.UniqueID = RowNumCTE.UniqueID
WHERE RowNumCTE.row_num > 1;
-- -----------------------------------------------------------------------------------------------------------------
SELECT COUNT(*) AS total_entries
FROM nashvillehousingdatafordatacleaning;

CREATE TABLE nashvillehousing_backup_3 AS
SELECT * FROM nashvillehousingdatafordatacleaning;


-- SELECT n.*, RowNumCTE.row_num
-- FROM nashvillehousing_backup_3  n
-- LEFT JOIN (
--     SELECT *,
--            ROW_NUMBER() OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
--                              ORDER BY UniqueID) AS row_num
--     FROM nashvillehousing_backup_3 
-- ) AS RowNumCTE ON n.ParcelID = RowNumCTE.ParcelID
--               AND n.PropertyAddress = RowNumCTE.PropertyAddress
--               AND n.SalePrice = RowNumCTE.SalePrice
--               AND n.SaleDate = RowNumCTE.SaleDate
--               AND n.LegalReference = RowNumCTE.LegalReference
--               AND n.UniqueID = RowNumCTE.UniqueID
-- WHERE RowNumCTE.row_num > 1;


-- deleting the duplicate entires from the dataset:
CREATE TABLE nashvillehousing_backup4 AS
SELECT * FROM nashvillehousingdatafordatacleaning;

SELECT * FROM nashvillehousing_backup4;

SELECT COUNT(*) AS total_entries
FROM nashvillehousing_backup4;


SELECT COUNT(*) AS total_entries
FROM nashvillehousingdatafordatacleaning; -- 56477 total entries

DELETE n
FROM nashvillehousingdatafordatacleaning n
LEFT JOIN (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
                             ORDER BY UniqueID) AS row_num
    FROM nashvillehousingdatafordatacleaning
) AS RowNumCTE ON n.ParcelID = RowNumCTE.ParcelID
              AND n.PropertyAddress = RowNumCTE.PropertyAddress
              AND n.SalePrice = RowNumCTE.SalePrice
              AND n.SaleDate = RowNumCTE.SaleDate
              AND n.LegalReference = RowNumCTE.LegalReference
              AND n.UniqueID = RowNumCTE.UniqueID
WHERE RowNumCTE.row_num > 1;

-- recounting the nuumber of entries to see if duplcates removed:
SELECT COUNT(*) AS total_entries_after_removing_duplicates
FROM nashvillehousingdatafordatacleaning; -- 56373 total entires


-- As there are 104 less entries so this shows that the duplicates entries have been removed .


-- Deleting the unimprtant columns in the original table:
SELECT *
FROM nashvillehousingdatafordatacleaning;

ALTER TABLE nashvillehousingdatafordatacleaning
DROP COLUMN OwnerAddress, DROP COLUMN TaxDistrict, DROP COLUMN PropertyAddress;

ALTER TABLE nashvillehousingdatafordatacleaning
DROP COLUMN SaleDate;