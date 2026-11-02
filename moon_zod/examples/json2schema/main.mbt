///|
fn main {
  let user_schema = @moon_zod.object({
    "id": @moon_zod.number(),
    "name": @moon_zod.string(),
    "username": @moon_zod.string(),
    "email": @moon_zod.string(),
    "address": @moon_zod.object({
      "street": @moon_zod.string(),
      "suite": @moon_zod.string(),
      "city": @moon_zod.string(),
      "zipcode": @moon_zod.string(),
      "geo": @moon_zod.object({
        "lat": @moon_zod.string(),
        "lng": @moon_zod.string(),
      }),
    }),
    "phone": @moon_zod.string(),
    "website": @moon_zod.string(),
    "company": @moon_zod.object({
      "name": @moon_zod.string(),
      "catchPhrase": @moon_zod.string(),
      "bs": @moon_zod.string(),
    }),
  })

  let user_json = get_user_json()
  println("Validating original JSON against schema...")
  let result = user_schema.parse(user_json)
  match result {
    Err(_) =>
      println(
        "Original JSON is invalid — this should not happen with the provided get_user_json()!",
      )
    Ok(_) => println("Original JSON is valid!")
  }

  let post_schema = @moon_zod.object({
    "userId": @moon_zod.number(),
    "id": @moon_zod.number(),
    "title": @moon_zod.string(),
    "body": @moon_zod.string(),
  })

  let post_json = get_post_json()
  println("Validating original JSON against schema...")
  let result = post_schema.parse(post_json)
  match result {
    Err(_) =>
      println(
        "Original JSON is invalid — this should not happen with the provided get_post_json()!",
      )
    Ok(_) => println("Original JSON is valid!")
  }

  let get_github_rust_repo_schema = @moon_zod.object({
    "id": @moon_zod.number(),
    "node_id": @moon_zod.string(),
    "name": @moon_zod.string(),
    "full_name": @moon_zod.string(),
    "private": @moon_zod.boolean(),
    "owner": @moon_zod.object({
      "login": @moon_zod.string(),
      "id": @moon_zod.number(),
      "node_id": @moon_zod.string(),
      "avatar_url": @moon_zod.string(),
      "gravatar_id": @moon_zod.string(),
      "url": @moon_zod.string(),
      "html_url": @moon_zod.string(),
      "followers_url": @moon_zod.string(),
      "following_url": @moon_zod.string(),
      "gists_url": @moon_zod.string(),
      "starred_url": @moon_zod.string(),
      "subscriptions_url": @moon_zod.string(),
      "organizations_url": @moon_zod.string(),
      "repos_url": @moon_zod.string(),
      "events_url": @moon_zod.string(),
      "received_events_url": @moon_zod.string(),
      "type": @moon_zod.string(),
      "site_admin": @moon_zod.boolean(),
    }),
    "html_url": @moon_zod.string(),
    "description": @moon_zod.string(),
    "fork": @moon_zod.boolean(),
    "url": @moon_zod.string(),
    "forks_url": @moon_zod.string(),
    "keys_url": @moon_zod.string(),
    "collaborators_url": @moon_zod.string(),
    "teams_url": @moon_zod.string(),
    "hooks_url": @moon_zod.string(),
    "issue_events_url": @moon_zod.string(),
    "events_url": @moon_zod.string(),
    "assignees_url": @moon_zod.string(),
    "branches_url": @moon_zod.string(),
    "tags_url": @moon_zod.string(),
    "blobs_url": @moon_zod.string(),
    "git_tags_url": @moon_zod.string(),
    "git_refs_url": @moon_zod.string(),
    "trees_url": @moon_zod.string(),
    "statuses_url": @moon_zod.string(),
    "languages_url": @moon_zod.string(),
    "stargazers_url": @moon_zod.string(),
    "contributors_url": @moon_zod.string(),
    "subscribers_url": @moon_zod.string(),
    "subscription_url": @moon_zod.string(),
    "commits_url": @moon_zod.string(),
    "git_commits_url": @moon_zod.string(),
    "comments_url": @moon_zod.string(),
    "issue_comment_url": @moon_zod.string(),
    "contents_url": @moon_zod.string(),
    "compare_url": @moon_zod.string(),
    "merges_url": @moon_zod.string(),
    "archive_url": @moon_zod.string(),
    "downloads_url": @moon_zod.string(),
    "issues_url": @moon_zod.string(),
    "pulls_url": @moon_zod.string(),
    "milestones_url": @moon_zod.string(),
    "notifications_url": @moon_zod.string(),
    "labels_url": @moon_zod.string(),
    "releases_url": @moon_zod.string(),
    "deployments_url": @moon_zod.string(),
    "created_at": @moon_zod.string(),
    "updated_at": @moon_zod.string(),
    "pushed_at": @moon_zod.string(),
    "git_url": @moon_zod.string(),
    "ssh_url": @moon_zod.string(),
    "clone_url": @moon_zod.string(),
    "svn_url": @moon_zod.string(),
    "homepage": @moon_zod.string(),
    "size": @moon_zod.number(),
    "stargazers_count": @moon_zod.number(),
    "watchers_count": @moon_zod.number(),
    "language": @moon_zod.string(),
    "has_issues": @moon_zod.boolean(),
    "has_projects": @moon_zod.boolean(),
    "has_downloads": @moon_zod.boolean(),
    "has_wiki": @moon_zod.boolean(),
    "has_pages": @moon_zod.boolean(),
    "has_discussions": @moon_zod.boolean(),
    "forks_count": @moon_zod.number(),
    "mirror_url": @moon_zod.null(),
    "archived": @moon_zod.boolean(),
    "disabled": @moon_zod.boolean(),
    "open_issues_count": @moon_zod.number(),
    "license": @moon_zod.object({
      "key": @moon_zod.string(),
      "name": @moon_zod.string(),
      "spdx_id": @moon_zod.string(),
      "url": @moon_zod.string(),
      "node_id": @moon_zod.string(),
    }),
    "allow_forking": @moon_zod.boolean(),
    "is_template": @moon_zod.boolean(),
    "web_commit_signoff_required": @moon_zod.boolean(),
    "has_pull_requests": @moon_zod.boolean(),
    "network_count": @moon_zod.number(),
    "subscribers_count": @moon_zod.number(),
  })

  let github_rust_repo_json = get_github_rust_repo_json()
  println("Validating original JSON against schema...")
  let result = get_github_rust_repo_schema.parse(github_rust_repo_json)
  match result {
    Err(_) =>
      println(
        "Original JSON is invalid — this should not happen with the provided get_github_rust_repo_json()!",
      )
    Ok(_) => println("Original JSON is valid!")
  }
}

///|
fn get_user_json() -> Json {
  {
    "id": 1,
    "name": "Leanne Graham",
    "username": "Bret",
    "email": "Sincere@april.biz",
    "address": {
      "street": "Kulas Light",
      "suite": "Apt. 556",
      "city": "Gwenborough",
      "zipcode": "92998-3874",
      "geo": { "lat": "-37.3159", "lng": "81.1496" },
    },
    "phone": "1-770-736-8031 x56442",
    "website": "hildegard.org",
    "company": {
      "name": "Romaguera-Crona",
      "catchPhrase": "Multi-layered client-server neural-net",
      "bs": "harness real-time e-markets",
    },
  }
}

///|
fn get_post_json() -> Json {
  {
    "userId": 1,
    "id": 1,
    "title": "sunt aut facere repellat provident occaecati excepturi optio reprehenderit",
    "body": "quia et suscipit\nsuscipit recusandae consequuntur expedita et cum\nreprehenderit molestiae ut ut quas totam\nnostrum rerum est autem sunt rem eveniet architecto",
  }
}

///|
fn get_github_rust_repo_json() -> Json {
  {
    "id": 724712,
    "node_id": "MDEwOlJlcG9zaXRvcnk3MjQ3MTI=",
    "name": "rust",
    "full_name": "rust-lang/rust",
    "private": false,
    "owner": {
      "login": "rust-lang",
      "id": 5430905,
      "node_id": "MDEyOk9yZ2FuaXphdGlvbjU0MzA5MDU=",
      "avatar_url": "https://avatars.githubusercontent.com/u/5430905?v=4",
      "gravatar_id": "",
      "url": "https://api.github.com/users/rust-lang",
      "html_url": "https://github.com/rust-lang",
      "followers_url": "https://api.github.com/users/rust-lang/followers",
      "following_url": "https://api.github.com/users/rust-lang/following{/other_user}",
      "gists_url": "https://api.github.com/users/rust-lang/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/rust-lang/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/rust-lang/subscriptions",
      "organizations_url": "https://api.github.com/users/rust-lang/orgs",
      "repos_url": "https://api.github.com/users/rust-lang/repos",
      "events_url": "https://api.github.com/users/rust-lang/events{/privacy}",
      "received_events_url": "https://api.github.com/users/rust-lang/received_events",
      "type": "Organization",
      "site_admin": false,
    },
    "html_url": "https://github.com/rust-lang/rust",
    "description": "Empowering everyone to build reliable and efficient software.",
    "fork": false,
    "url": "https://api.github.com/repos/rust-lang/rust",
    "forks_url": "https://api.github.com/repos/rust-lang/rust/forks",
    "keys_url": "https://api.github.com/repos/rust-lang/rust/keys{/key_id}",
    "collaborators_url": "https://api.github.com/repos/rust-lang/rust/collaborators{/collaborator}",
    "teams_url": "https://api.github.com/repos/rust-lang/rust/teams",
    "hooks_url": "https://api.github.com/repos/rust-lang/rust/hooks",
    "issue_events_url": "https://api.github.com/repos/rust-lang/rust/issues/events{/number}",
    "events_url": "https://api.github.com/repos/rust-lang/rust/events",
    "assignees_url": "https://api.github.com/repos/rust-lang/rust/assignees{/user}",
    "branches_url": "https://api.github.com/repos/rust-lang/rust/branches{/branch}",
    "tags_url": "https://api.github.com/repos/rust-lang/rust/tags",
    "blobs_url": "https://api.github.com/repos/rust-lang/rust/git/blobs{/sha}",
    "git_tags_url": "https://api.github.com/repos/rust-lang/rust/git/tags{/sha}",
    "git_refs_url": "https://api.github.com/repos/rust-lang/rust/git/refs{/sha}",
    "trees_url": "https://api.github.com/repos/rust-lang/rust/git/trees{/sha}",
    "statuses_url": "https://api.github.com/repos/rust-lang/rust/statuses/{sha}",
    "languages_url": "https://api.github.com/repos/rust-lang/rust/languages",
    "stargazers_url": "https://api.github.com/repos/rust-lang/rust/stargazers",
    "contributors_url": "https://api.github.com/repos/rust-lang/rust/contributors",
    "subscribers_url": "https://api.github.com/repos/rust-lang/rust/subscribers",
    "subscription_url": "https://api.github.com/repos/rust-lang/rust/subscription",
    "commits_url": "https://api.github.com/repos/rust-lang/rust/commits{/sha}",
    "git_commits_url": "https://api.github.com/repos/rust-lang/rust/git/commits{/sha}",
    "comments_url": "https://api.github.com/repos/rust-lang/rust/comments{/number}",
    "issue_comment_url": "https://api.github.com/repos/rust-lang/rust/issues/comments{/number}",
    "contents_url": "https://api.github.com/repos/rust-lang/rust/contents/{+path}",
    "compare_url": "https://api.github.com/repos/rust-lang/rust/compare/{base}...{head}",
    "merges_url": "https://api.github.com/repos/rust-lang/rust/merges",
    "archive_url": "https://api.github.com/repos/rust-lang/rust/{archive_format}{/ref}",
    "downloads_url": "https://api.github.com/repos/rust-lang/rust/downloads",
    "issues_url": "https://api.github.com/repos/rust-lang/rust/issues{/number}",
    "pulls_url": "https://api.github.com/repos/rust-lang/rust/pulls{/number}",
    "milestones_url": "https://api.github.com/repos/rust-lang/rust/milestones{/number}",
    "notifications_url": "https://api.github.com/repos/rust-lang/rust/notifications{?since,all,participating}",
    "labels_url": "https://api.github.com/repos/rust-lang/rust/labels{/name}",
    "releases_url": "https://api.github.com/repos/rust-lang/rust/releases{/id}",
    "deployments_url": "https://api.github.com/repos/rust-lang/rust/deployments",
    "created_at": "2010-06-16T20:39:03Z",
    "updated_at": "2026-06-05T16:56:05Z",
    "pushed_at": "2026-06-05T16:57:43Z",
    "git_url": "git://github.com/rust-lang/rust.git",
    "ssh_url": "git@github.com:rust-lang/rust.git",
    "clone_url": "https://github.com/rust-lang/rust.git",
    "svn_url": "https://github.com/rust-lang/rust",
    "homepage": "https://www.rust-lang.org",
    "size": 913226,
    "stargazers_count": 113585,
    "watchers_count": 113585,
    "language": "Rust",
    "has_issues": true,
    "has_projects": true,
    "has_downloads": true,
    "has_wiki": false,
    "has_pages": false,
    "has_discussions": false,
    "forks_count": 15080,
    "mirror_url": null,
    "archived": false,
    "disabled": false,
    "open_issues_count": 12502,
    "license": {
      "key": "apache-2.0",
      "name": "Apache License 2.0",
      "spdx_id": "Apache-2.0",
      "url": "https://api.github.com/licenses/apache-2.0",
      "node_id": "MDc6TGljZW5zZTI=",
    },
    "allow_forking": true,
    "is_template": false,
    "web_commit_signoff_required": false,
    "has_pull_requests": true,
    "network_count": 15080,
    "subscribers_count": 1576,
  }
}
