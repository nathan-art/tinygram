package foo;//https://projet-wcd.ew.r.appspot.com

import java.util.ArrayList;
import java.util.Collection;
//import java.io.Console;
import java.util.Date;
//import java.util.HashSet;
//import java.util.Iterator;
import java.util.List;
//import java.util.Random;

import com.google.api.server.spi.auth.common.User;
import com.google.api.server.spi.config.Api;
import com.google.api.server.spi.config.ApiMethod;
import com.google.api.server.spi.config.ApiMethod.HttpMethod;
import com.google.api.server.spi.config.ApiNamespace;
import com.google.api.server.spi.config.Named;
import com.google.api.server.spi.config.Nullable;
import com.google.api.server.spi.response.CollectionResponse;
import com.google.api.server.spi.response.UnauthorizedException;
import com.google.api.services.discovery.model.RestMethod.Request;
import com.google.api.server.spi.auth.EspAuthenticator;

import com.google.appengine.api.datastore.Cursor;
import com.google.appengine.api.datastore.DatastoreService;
import com.google.appengine.api.datastore.DatastoreServiceFactory;
import com.google.appengine.api.datastore.Entity;
import com.google.appengine.api.datastore.EntityNotFoundException;
import com.google.appengine.api.datastore.FetchOptions;
import com.google.appengine.api.datastore.Key;
import com.google.appengine.api.datastore.KeyFactory;
import com.google.appengine.api.datastore.Query;
import com.google.appengine.api.datastore.PreparedQuery;
import com.google.appengine.api.datastore.PropertyProjection;
import com.google.appengine.api.datastore.PreparedQuery.TooManyResultsException;
import com.google.appengine.api.datastore.Query.CompositeFilter;
import com.google.appengine.api.datastore.Query.CompositeFilterOperator;
import com.google.appengine.api.datastore.Query.Filter;
import com.google.appengine.api.datastore.Query.FilterOperator;
import com.google.appengine.api.datastore.Query.FilterPredicate;
import com.google.appengine.api.datastore.Query.SortDirection;
import com.google.appengine.api.datastore.TransactionOptions;
import com.google.appengine.repackaged.com.google.datastore.v1.PropertyFilter;

import endpoints.repackaged.com.google.api.Http;

import com.google.appengine.api.datastore.QueryResultList;
import com.google.appengine.api.datastore.Transaction;

@Api(name = "myApi",
     version = "v1",
     audiences = "305866023480-undf89hsfe7vr49jr3jmckuu582esui8.apps.googleusercontent.com",
  	 clientIds = "305866023480-undf89hsfe7vr49jr3jmckuu582esui8.apps.googleusercontent.com",
     namespace =
     @ApiNamespace(
		   ownerDomain = "helloworld.example.com",
		   ownerName = "helloworld.example.com",
		   packagePath = "")
     )

public class Endpoint {

    @ApiMethod(name = "hello", httpMethod = HttpMethod.GET)
	public User Hello(User user) throws UnauthorizedException {
        if (user == null) {
			throw new UnauthorizedException("Invalid credentials");
		}
        //System.out.println("Hello:"+user.toString());
		return user;
	}

    //les deux posts les plus récents ?
	@ApiMethod(name = "retrievePosts", httpMethod = HttpMethod.GET)
	public CollectionResponse<Entity> retrievePosts(@Nullable @Named("email") String email, @Nullable @Named("next") String cursorString)
			throws UnauthorizedException {

        System.out.println("GET NEW POST");

		Query q = new Query("Post");
		    //setFilter(new FilterPredicate("owner", FilterOperator.EQUAL, email));

		// Multiple projection require a composite index
		// owner is automatically projected...
		// q.addProjection(new PropertyProjection("body", String.class));
		// q.addProjection(new PropertyProjection("date", java.util.Date.class));
		// q.addProjection(new PropertyProjection("likec", Integer.class));
		// q.addProjection(new PropertyProjection("url", String.class));

		// looks like a good idea but...
		// require a composite index
		// - kind: Post
		//  properties:
		//  - name: owner
		//  - name: date
		//    direction: desc

		// q.addSort("date", SortDirection.DESCENDING);

		DatastoreService datastore = DatastoreServiceFactory.getDatastoreService();
		PreparedQuery pq = datastore.prepare(q);

		FetchOptions fetchOptions = FetchOptions.Builder.withLimit(5);

		if (cursorString != null) {
			fetchOptions.startCursor(Cursor.fromWebSafeString(cursorString));
		}

		QueryResultList<Entity> results = pq.asQueryResultList(fetchOptions);
		cursorString = results.getCursor().toWebSafeString();

		return CollectionResponse.<Entity>builder().setItems(results).setNextPageToken(cursorString).build();
	}


	@ApiMethod(name = "postMsg", httpMethod = HttpMethod.POST)
	public Entity postMsg(User user, @Named("email") String email, PostMessage pm) throws UnauthorizedException {

		if (user == null) {
			throw new UnauthorizedException("Invalid credentials");
		}
        
		Entity e = new Entity("Post", Long.MAX_VALUE-(new Date()).getTime()+":"+email);
		e.setProperty("owner", email);
        e.setProperty("ownerName", pm.owner);
		e.setProperty("url", pm.url);
		e.setProperty("body", pm.body);
		e.setProperty("cptlike", 0);
		e.setProperty("date", new Date());

///		Solution pour pas projeter les listes
//		Entity pi = new Entity("PostIndex", e.getKey());
//		HashSet<String> rec=new HashSet<String>();
//		pi.setProperty("receivers",rec);
        System.out.println("NEW ENTITY:");
        System.out.println(e);
		
		DatastoreService datastore = DatastoreServiceFactory.getDatastoreService();
		Transaction txn = datastore.beginTransaction();
		datastore.put(e);
//		datastore.put(pi);
		txn.commit();
		return e;
	}

	@ApiMethod(name = "isLiked", httpMethod = ApiMethod.HttpMethod.GET)
	public Entity isLiked(User user, @Named("email") String email, @Named("postMessagekey") String postMessageID) {

		if (user == null) {
			return null;
		}

		Key postKey = KeyFactory.createKey("Post", postMessageID);
        Key likesKey = KeyFactory.createKey(postKey,"Likes", postMessageID);

		DatastoreService datastore = DatastoreServiceFactory.getDatastoreService();
		Query q = new Query("Likes")
			.setKeysOnly()
			.setFilter(CompositeFilterOperator.and(
				FilterOperator.EQUAL.of(Entity.KEY_RESERVED_PROPERTY, likesKey),
				FilterOperator.EQUAL.of("likes", email)
			));
			// .setFilter(new FilterPredicate(Entity.KEY_RESERVED_PROPERTY, FilterOperator.EQUAL, likesKey))
			// .setFilter(new FilterPredicate("likes", FilterOperator.EQUAL, email));
		
		QueryResultList<Entity> qr = datastore.prepare(q).asQueryResultList(FetchOptions.Builder.withLimit(1));
		// Entity qr = datastore.prepare(q).asSingleEntity();

		if (qr.isEmpty()) {
			return null;
		}
		return qr.get(0);
	}

    @ApiMethod(name = "like", httpMethod = ApiMethod.HttpMethod.POST)
    public Entity like(User user, @Named("email") String email, @Named("postMessageKey") String postMessageID) throws UnauthorizedException {

		if (user == null) {
			throw new UnauthorizedException("Invalid credentials");
		}

        Key postKey = KeyFactory.createKey("Post", postMessageID);
		//Key likesKey = KeyFactory.createKey("Likes", postMessageID);
        Key likesKey = KeyFactory.createKey(postKey,"Likes", postMessageID);

		if (isLiked(user, email, postMessageID) != null) {
			return null;
		}

        DatastoreService datastore = DatastoreServiceFactory.getDatastoreService();
		Transaction txn = datastore.beginTransaction();
        Entity message = null;
		Entity likes = null;
        try {
            message = datastore.get(postKey);
            message.setProperty("cptlike", (long)message.getProperty("cptlike")+(long)1);
			try {
				likes = datastore.get(likesKey);
				ArrayList<String> likesList = (ArrayList<String>) likes.getProperty("likes");
				likesList.add(email);
				datastore.put(likes);
			} catch (EntityNotFoundException e) {
				ArrayList<String> likesList = new ArrayList<String>();
				likesList.add(email);
				likes = new Entity(likesKey);
				likes.setProperty("likes", likesList);
				datastore.put(likes);
			}
            datastore.put(message);
        } catch (EntityNotFoundException e) {
            e.printStackTrace();
        }
        txn.commit();
        return message;
    }

	@ApiMethod(name = "likedPosts", httpMethod = ApiMethod.HttpMethod.GET)
	public CollectionResponse<Entity> likedPosts(User user, @Named("email") String email, @Nullable @Named("next") String cursorString) throws UnauthorizedException {

		if (user == null) {
			throw new UnauthorizedException("Invalid credentials");
		}

		DatastoreService datastore = DatastoreServiceFactory.getDatastoreService();
		Query q = new Query("Likes")
			.setKeysOnly()
			.setFilter(new FilterPredicate("likes", FilterOperator.EQUAL, email));

		PreparedQuery pq = datastore.prepare(q);
		FetchOptions fetchOptions = FetchOptions.Builder.withLimit(5);

		if (cursorString != null) {
			fetchOptions.startCursor(Cursor.fromWebSafeString(cursorString));
		}

		QueryResultList<Entity> qr = pq.asQueryResultList(fetchOptions);
		cursorString = qr.getCursor().toWebSafeString();

		ArrayList<Key> lpkeys = new ArrayList<Key>();
		qr.forEach(entity -> lpkeys.add(KeyFactory.createKey("Post", entity.getKey().getName())));

		Collection<Entity> results = (Collection<Entity>) datastore.get(lpkeys).values();

		return CollectionResponse.<Entity>builder().setItems(results).setNextPageToken(cursorString).build();
	}

	@ApiMethod(name = "follow", httpMethod = ApiMethod.HttpMethod.POST)
	public Entity follow(User user, @Named("email") String email, @Named("postMessageKey") String postMessageID) throws UnauthorizedException {
		if (user == null) {
			throw new UnauthorizedException("Invalid credentials");
		}

		Key postKey = KeyFactory.createKey("Post", postMessageID);

		DatastoreService datastore = DatastoreServiceFactory.getDatastoreService();
		Transaction txn = datastore.beginTransaction(TransactionOptions.Builder.withDefaults().setXG(true));
		Entity message = null;
		Entity follower = null;

		try {
			message = datastore.get(postKey);
			String owner = (String) message.getProperty("owner");
			Key ownerKey = KeyFactory.createKey("Follows", owner);

			try {
				follower = datastore.get(ownerKey);
				ArrayList<String> follows = (ArrayList<String>) follower.getProperty("follows");
				follows.add(email);
				follower.setProperty("follows", follows);
				follower.setProperty("follower_count", (Long) follower.getProperty("follower_count") + 1);
			} catch(EntityNotFoundException e) {
				follower = new Entity("Follows", owner);
				follower.setProperty("user", owner);
				ArrayList<String> follows = new ArrayList<String>();
				follows.add(email);
				follower.setProperty("follows", follows);
				follower.setProperty("follower_count", 1);
			}
			datastore.put(follower);
		} catch (EntityNotFoundException e) {
			e.printStackTrace();
		}

		txn.commit();
		return follower;
	}

	@ApiMethod(name = "followedPosts", httpMethod = ApiMethod.HttpMethod.GET)
	public CollectionResponse<Entity> followedPosts(User user, @Named("email") String email, @Nullable @Named("next") String cursorString) throws UnauthorizedException {

		if (user == null) {
			throw new UnauthorizedException("Invalid credentials");
		}

		DatastoreService datastore = DatastoreServiceFactory.getDatastoreService();
		Query q = new Query("Follows")
			.setKeysOnly()
			.setFilter(new FilterPredicate("follows", FilterOperator.EQUAL, email));
		
		PreparedQuery pq = datastore.prepare(q);
		FetchOptions fetchOptions = FetchOptions.Builder.withLimit(10);
		QueryResultList<Entity> qr = pq.asQueryResultList(fetchOptions);

		ArrayList<String> fusers = new ArrayList<String>();
		qr.forEach(entity -> fusers.add(entity.getKey().getName()));

		return CollectionResponse.<Entity>builder().setItems(qr).setNextPageToken(cursorString).build();
	}

	@ApiMethod(name = "followCount", httpMethod = ApiMethod.HttpMethod.GET)
	public Entity followCount(@Named("owner") String owner) {

		DatastoreService datastore = DatastoreServiceFactory.getDatastoreService();
		Key ownerKey = KeyFactory.createKey("Follows", owner);
		Query q = new Query("Follows")
			.setFilter(new FilterPredicate("user", FilterOperator.EQUAL, owner));
		
		PreparedQuery pq = datastore.prepare(q);
		long fcount = (long) pq.asSingleEntity().getProperty("follower_count");
		Entity result = new Entity(ownerKey);
		result.setProperty("follower_count", fcount);

		return result;
	}

}