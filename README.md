<h1>The Quickest Way to Build PostgreSQL GraphQL Backend With Jwt Authentication—PostGraphile</h1><h2 class="description">PostGraphile generates powerful, secure and fast GraphQL APIs very rapidly.</h2>
<p>An older verion of this article can be found here <a href=https://leapgraph.com/graphql-postgresql-postgraphile" rel="noopener" target="_blank">leapgraph.com</a>.</p>
<p>In previous iterations, <b>PostGraphQL</b> by Caleb Meredith was one of the most popular library for connecting GraphQL APIs and PostgreSQL Databases. <i>This article shows you how to turn your PostgreSQL database schema into an GraphQL API automatically with <a href="https://github.com/graphile/postgraphile" rel="noopener" target="_blank">PostGraphile</a></i>.<p>With <b>PostGraphile just in its beta period - <a href="https://github.com/graphile/postgraphile/releases/tag/v4.4.2-rc.0" rel="noopener" target="_blank">v4.4.2 Release Candidate 0</a></b><p>We will first <b>build a GraphQL API automatically with this library</b>.</header><main><h2>How to Connect GraphQL and PostgreSQL Automatically using PostGraphile and JWT (Example)</h2><p>Let us take an example of a PostgreSQL database for a blog.<p>To keep things simple, our database schema has three tables:<ol><li>Users<li>Posts<li>Comments</ol><p>First make sure Postgres is installed and running locally and then connect to the default db.<pre><code>

## Create Admin User

```sql
psql -c "CREATE USER admin WITH SUPERUSER PASSWORD 'admin'";
```

Then grant privileges and add login to user.

```sql
blog=# GRANT ALL PRIVILEGES ON DATABASE blog TO admin;
GRANT
blog=# ALTER ROLE ADMIN WITH LOGIN;
ALTER ROLE
```

## Create the db tables

```sql
psql -d blog -f database/schema.sql
```

## Granting privileges on tables

Why? Not sure yet.

```sql
blog=# grant all privileges on table users to admin;
GRANT
blog=# grant all privileges on table posts to admin;
GRANT
blog=# grant all privileges on table comments to admin;
GRANT
```

## Connecting to Postgraphile

You can now connect postgraphile to your database with:

```sql
pg-jwt-blog-demo npx postgraphile -c postgres://admin:admin@localhost/blog --enhance-graphiql

PostGraphile v4.4.2-rc.0 server listening on port 5000 🚀

  ‣ GraphQL API:         http://localhost:5000/graphql
  ‣ GraphiQL GUI/IDE:    http://localhost:5000/graphiql
  ‣ Postgres connection: postgres://admin:[SECRET]@localhost/blog
  ‣ Postgres schema(s):  public
  ‣ Documentation:       https://graphile.org/postgraphile/introduction/
  ‣ Join 8th Light in supporting PostGraphile development: https://graphile.org/sponsor/

* * *
```

### Create a user

```graphql

mutation {
  createUser (
    input: {
      user: {
        name: "Foo",
        email: "foo@example.com",
        password: "123456",
      }
    }) {
    user {
      id
      name
      email
      password
    }
  }
}

# {
#   "data": {
#     "createUser": {
#       "user": {
#         "id": 1,
#         "name": "Foo",
#         "email": "foo@example.com",
#         "password": "123456"
#       }
#     }
#   }
# }
```

## PostGraphile Authentication with JWT: Securing your GraphQL Express Server

To use PostGraphile with Javascript Web Tokens, we MUST supply a `--jwt-secret` on the CLI (or jwtsecret to the library option).

We issue PostGraphile a secret key and custom PostgreSQL data type, PostGraphile in turn encodes the content as a JWT token and signs it before returning it. We also need to supply a `--default-role` that is used for requests that don't specify one.

Create a guest role who wont be able to login:

```bash
➜  pg-jwt-blog-demo psql -d blog
psql (11.3, server 11.4)
Type "help" for help.

blog=# \du
blog=# CREATE ROLE guest;
CREATE ROLE
blog=# \du
blog=#

```

The following creates a new data type for our JWT tokens. See \h CREATE TYPE for options.

```sql
CREATE TYPE jwt_token AS (
  role TEXT,
  user_id INTEGER,
  name TEXT
);
```

The `role` in the `jwt_token` TYEP is for setting the PostgreSQL roles.

Then we need two PL/pgSQL functions: SIGNUP and SIGNIN. PL/pgSQL groups block computations for a series of queries inside the database server reducing extra roundtrips and eliminating multiple rounds of query parsing.

These two functions return the jwt_token type which PostGraphile will translate into a JWT.

The following creates the PL/pgSQL SIGNUP function. See \h CREATE FUNCTION for options.

```sql
CREATE FUNCTION SIGNUP(username TEXT, email TEXT, password TEXT) RETURNS jwt_token AS
$$
DECLARE
        token_information jwt_token;
BEGIN
        INSERT INTO users (name, email, password) VALUES ($1, $2, crypt($3, gen_salt('bf', 8)));
        SELECT 'admin', id, name
               INTO token_information
               FROM users
               WHERE users.email = $2;
        RETURN token_information::jwt_token;
END;
$$ LANGUAGE PLPGSQL VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION SIGNUP(username TEXT, email TEXT, password TEXT) TO guest;

```

And here is my CLI output:

```bash
blog=# CREATE FUNCTION SIGNUP(username TEXT, email TEXT, password TEXT) RETURNS jwt_token AS
blog-# $$
blog$# DECLARE
blog$#         token_information jwt_token;
blog$# BEGIN
blog$#         INSERT INTO users (name, email, password) VALUES ($1, $2, crypt($3, gen_salt('bf', 8)));
blog$#         SELECT 'admin', id, name
blog$#                INTO token_information
blog$#                FROM users
blog$#                WHERE users.email = $2;
blog$#         RETURN token_information::jwt_token;
blog$# END;
blog$# $$ LANGUAGE PLPGSQL VOLATILE SECURITY DEFINER;
CREATE FUNCTION
blog=#
blog=# GRANT EXECUTE ON FUNCTION SIGNUP(username TEXT, email TEXT, password TEXT) TO guest;
GRANT
```

The following creates the PL/pgSQL SIGNUP function:

```sql
CREATE FUNCTION SIGNIN(email TEXT, password TEXT) RETURNS jwt_token AS
$$
DECLARE
        token_information jwt_token;
BEGIN
        SELECT 'admin', id, name
               INTO token_information
               FROM users
               WHERE users.email = $1
                     AND users.password = crypt($2, users.password);
       RETURN token_information::jwt_token;
END;
$$ LANGUAGE PLPGSQL VOLATILE STRICT SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION SIGNIN(email TEXT, password TEXT) TO guest;
```

And here is my CLI output:

```bash
blog=# CREATE FUNCTION SIGNIN(email TEXT, password TEXT) RETURNS jwt_token AS
blog-# $$
blog$# DECLARE
blog$#         token_information jwt_token;
blog$# BEGIN
blog$#         SELECT 'admin', id, name
blog$#                INTO token_information
blog$#                FROM users
blog$#                WHERE users.email = $1
blog$#                      AND users.password = crypt($2, users.password);
blog$#        RETURN token_information::jwt_token;
blog$# END;
blog$# $$ LANGUAGE PLPGSQL VOLATILE STRICT SECURITY DEFINER;
CREATE FUNCTION
blog=#
blog=# GRANT EXECUTE ON FUNCTION SIGNIN(email TEXT, password TEXT) TO guest;
GRANT
```

Now that both functions are now created, we need to issue PostGraphile with a secret key and the name of the token type:
Replace jwtSecret value with a random string. For example, run `SecureRandom.uuid` in Rails console or use <https://www.uuidgenerator.net/>.

```bash
npx postgraphile -c postgres://admin:admin@localhost/blog \
--watch \
--jwt-token-identifier public.jwt_token \
--jwt-secret 63091a1c-60c4-4d9d-8202-ae8bebce48cb \
--default-role guest \
--show-error-stack \
--enhance-graphiql
```

Start PostGraphile and test jwt:

```graphql
mutation {
  signup (
    input: {
      username: "Jill",
      email: "jill@example.com",
      password: "123456"
    }) {
    jwtToken
  }
}
```

If it complains that "function gen_salt(unknown, integer) does not exist", add and test PostgreSQL's pgcrypto extension as follows:

```sql
create extension if not exists "pgcrypto";
```

And here is my CLI output:

```bash
blog=# create extension if not exists "pgcrypto";
CREATE EXTENSION
```

If you re-run the `SignUp` mutation you get this output:

```json
{
  "data": {
    "signup": {
      "jwtToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYWRtaW4iLCJ1c2VyX2lkIjozLCJuYW1lIjoiSmlsbCIsImlhdCI6MTU2MjE0NzA3NSwiZXhwIjoxNTYyMjMzNDc1LCJhdWQiOiJwb3N0Z3JhcGhpbGUiLCJpc3MiOiJwb3N0Z3JhcGhpbGUifQ.76ESiSzAUlltiOpcHRJPZZSy6rXFLU8Rm32jFwkQyBo"
    }
  }
}
```

Works.

Let's try to confirm whether our new user Jill was created successfully:

```graphql
query TestingJill {
  userByEmail (
    email: "jill@example.com"
  ) {
    id
    name
    email
  }
}
```

We get back permission errors because we need to be signed in to access this:

```json
{
  "errors": [
    {
      "message": "permission denied for table users",
      "locations": [
        {
          "line": 39,
          "column": 3
        }
      ],
      "path": [
        "userByEmail"
      ],
      "stack": "error: permission denied for table users\n at ..."
    }
  ],
  "data": {
    "userByEmail": null
  }
}
```

We get the same `permission denied` errors when we try to query anything else too. We will come back to this later.

We can use the newly created token to log in as follows. Open the `Headers` console in graphiql and add the token we got back above. Note there are no quotes on the value. This is always strange for me to look at.

```json
{
"Authorization": Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYWRtaW4iLCJ1c2VyX2lkIjozLCJuYW1lIjoiSmlsbCIsImlhdCI6MTU2MjE0NzA3NSwiZXhwIjoxNTYyMjMzNDc1LCJhdWQiOiJwb3N0Z3JhcGhpbGUiLCJpc3MiOiJwb3N0Z3JhcGhpbGUifQ.76ESiSzAUlltiOpcHRJPZZSy6rXFLU8Rm32j
}
```

The following will allow the `guest` role to query posts and users. Remember that our `guest` role is set as our `default role`.
You can run `postgraphile` in the terminal to see details on what each flag does.

```bash
$ psql -d blog
blog=# GRANT SELECT ON posts TO guest;
GRANT
blog=# GRANT SELECT ON users TO guest;
GRANT
blog=# \q
```

Running this query now works:

```graphql
query AllUsers {
allUsers{
  edges{
    node{
      name
    }
  }
}
  allPosts {
    edges {
      node {
        id
      }
    }
  }
}
```
