select * 
from netflix_raw
where concat(upper(title),type) in (select concat(upper(title),type)
from netflix_raw
group by (upper(title),type)
having count(*) > 1)
order by title;

-- new table directors
select show_id , TRIM(UNNEST(STRING_TO_ARRAY(director, ','))) AS director
into netflix_directors
from netflix_raw

select * 
from netflix_directors

-- new table country
select show_id , TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS country
into netflix_countrys
from netflix_raw

select *
from netflix_countrys

-- new table cast
select show_id , TRIM(UNNEST(STRING_TO_ARRAY("cast" , ','))) AS cast
into netflix_casts
from netflix_raw

select *
from netflix_casts

-- new table listed_in
select show_id , TRIM(UNNEST(STRING_TO_ARRAY(listed_in , ','))) AS genre
into netflix_genre
from netflix_raw

select *
from netflix_genre

-- populate missing values in country columns
insert into netflix_countrys 
select show_id, m.country
from netflix_raw as nr
inner join (
	select director, country
	from netflix_countrys nc
	inner join netflix_directors nd
	on nc.show_id = nd.show_id
	group by director, country
) as m 
on nr.director = m.director	
where nr.country is null

-- remove duplicates values
with cte as (
select *
, ROW_NUMBER() over (partition by title, type order by show_id) as rn
from netflix_raw
)

-- create netflix final table
select show_id, title, "type", cast(date_added as date) as date_added, release_year,
rating, case when duration is null then rating else duration end as duration, description
into netflix
from cte

select * 
from netflix

/* 1. For each director count the number of movies and tv shows created by them in separator 
 columns for directors who have created tv shows and movies both */
 select director, 
 COUNT(DISTINCT case when n.type = 'Movie' then n.show_id end) as no_of_movies,
 COUNT(DISTINCT	case when n.type = 'TV Show' then n.show_id end) as no_of_tv_shows
 from netflix as n
 inner join netflix_directors as nd
 on n.show_id = nd.show_id
 group by director
 having count(distinct type)>1

 -- 2. Which country has the highest number of comedy movies
 select country, count(distinct n.show_id) as no_of_comedy_movies
 from netflix n
 inner join netflix_countrys nc on n.show_id = nc.show_id
 inner join netflix_genre ng on n.show_id = ng.show_id
 where lower(genre)='comedies' and "type"='Movie'
 group by country
 order by no_of_comedy_movies desc
 limit 1

/* 3. For each year (as per date added to Netflix), which director has maximum number of 
 movies released */
 with cte as (
 select EXTRACT(YEAR FROM date_added) as date_year, director, count(distinct n.show_id) as no_of_movies
 from netflix n
 inner join netflix_directors nd on n.show_id = nd.show_id
 where n.type='Movie'
 group by EXTRACT(YEAR FROM date_added), director
 )
 , cte2 as (
 select *,
 ROW_NUMBER() over (partition by date_year order by no_of_movies desc, director) as rn
 from cte
 )

 select *
 from cte2
 where rn=1
 order by date_year desc

 -- 4. What is the average duration of movies in each genre
 select genre, avg(CAST(REPLACE(duration, 'min', '') AS INT)) as avg_duration
 from netflix n
 inner join netflix_genre ng on n.show_id = ng.show_id
 where "type"='Movie'
 group by genre

 /* 5. Find the list of directors who have created horror and comedy movies both. 
 Display director names along with number of comedy and horror movies directed by them */
 select director, 
 COUNT(DISTINCT case when lower(genre)='horror movies' then n.show_id end) as no_of_horror,
 COUNT(DISTINCT case when lower(genre)='comedies' then n.show_id end) as no_of_horror
 from netflix n
 inner join netflix_genre ng on n.show_id = ng.show_id
 inner join netflix_directors nd on n.show_id = nd.show_id
 where lower(genre) in ('horror movies','comedies')
 group by director
 having count(distinct genre)=2
 

