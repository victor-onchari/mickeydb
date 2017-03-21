package com.justeat.mickeydb.generator

import com.justeat.mickeydb.MickeyDatabaseModel
import com.justeat.mickeydb.ModelUtil
import com.justeat.mickeydb.mickeyLang.ActionStatement
import com.justeat.mickeydb.mickeyLang.ColumnDef
import com.justeat.mickeydb.mickeyLang.ColumnSource
import com.justeat.mickeydb.mickeyLang.ContentUri
import com.justeat.mickeydb.mickeyLang.ContentUriParamSegment
import com.justeat.mickeydb.mickeyLang.CreateTableStatement
import com.justeat.mickeydb.mickeyLang.CreateViewStatement
import com.justeat.mickeydb.mickeyLang.ResultColumn
import com.justeat.mickeydb.mickeyLang.TableDefinition

import static extension com.justeat.mickeydb.ModelUtil.*
import static extension com.justeat.mickeydb.Strings.*
import com.justeat.mickeydb.mickeyLang.ColumnType
import com.justeat.mickeydb.ContentUris

class ContentProviderContractGenerator {
	def CharSequence generate(MickeyDatabaseModel model, ContentUris content) '''	
		«var snapshot = model.snapshot»
		/*
		 * Generated by MickeyDB
		 */
		package «model.packageName»;
		
		import android.net.Uri;
		import android.provider.BaseColumns;
		import com.justeat.mickeydb.AbstractValuesBuilder;
		import com.justeat.mickeydb.Mickey;
		import com.justeat.mickeydb.MickeyUriBuilder;
		import java.lang.reflect.Field;			
		import java.util.Collections;
		import java.util.HashSet;
		import java.util.HashMap;
		import java.util.Set;
		import java.util.Map;
		
		public class «model.databaseName»Contract  {
		    public static final String CONTENT_AUTHORITY = initAuthority();
		
			private static String initAuthority() {
				String authority = "«model.packageName».«model.databaseName.toLowerCase»";
		
				try {
				  		
				  		ClassLoader loader = «model.databaseName.pascalize»Contract.class.getClassLoader();
				  		
					Class<?> clz = loader.loadClass("«model.packageName».«model.databaseName.pascalize»ContentProviderAuthority");
					Field declaredField = clz.getDeclaredField("CONTENT_AUTHORITY");
					
					authority = declaredField.get(null).toString();
				} catch (ClassNotFoundException | NoSuchFieldException | IllegalArgumentException | IllegalAccessException ignore) {
				}
				
				return authority;
			}
			
			   public static final Uri BASE_CONTENT_URI = Uri.parse("content://" + CONTENT_AUTHORITY);
		
			«FOR tbl : snapshot.tables»
				interface «tbl.name.pascalize»Columns {
					«FOR col : tbl.columnDefs.filter([!name.equals("_id")])»
						String «col.name.underscore.toUpperCase» = "«col.name»";
					«ENDFOR»
				}
				
			«ENDFOR»
			«FOR vw : snapshot.views»
				interface «vw.name.pascalize»Columns {
					«FOR col : vw.getViewResultColumns.filter([!name.equals("_id")])»
						«generateInterfaceMemberForResultColumn(col)»
					«ENDFOR»
				}
			«ENDFOR»
			«FOR tbl : model.initTables»
				interface «tbl.name.pascalize»Columns {
					«FOR col : tbl.columnDefs.filter([!name.equals("_id")])»
						String «col.name.underscore.toUpperCase» = "«col.name»";
					«ENDFOR»
				}
				
			«ENDFOR»
			«FOR vw : model.initViews»
				interface «vw.name.pascalize»Columns {
					«FOR col : vw.getViewResultColumns.filter([!name.equals("_id")])»
						«generateInterfaceMemberForResultColumn(col)»
					«ENDFOR»
				}
				
			«ENDFOR»
			
			«FOR tbl : snapshot.tables»
				«generateContractItem(model, snapshot, tbl, content)»
			«ENDFOR»
		
			«FOR vw : snapshot.views»
				«generateContractItem(model, snapshot, vw, content)»
			«ENDFOR»
			
			«FOR tbl : model.initTables»
				«generateContractItem(model, snapshot, tbl, content)»
			«ENDFOR»
		
			«FOR vw : model.initViews»
				«generateContractItem(model, snapshot, vw, content)»
			«ENDFOR»

			static final Map<Uri, Set<Uri>> REFERENCING_VIEWS;

			static {
				Map<Uri, Set<Uri>> map = new HashMap<>();
				
				«FOR tbl : snapshot.tables»
					map.put(«tbl.name.pascalize».CONTENT_URI, «tbl.name.pascalize».VIEW_URIS);
				«ENDFOR»
				«FOR vw : snapshot.views»
					map.put(«vw.name.pascalize».CONTENT_URI, «vw.name.pascalize».VIEW_URIS);
				«ENDFOR»
				«FOR tbl : model.initTables»
					map.put(«tbl.name.pascalize».CONTENT_URI, «tbl.name.pascalize».VIEW_URIS);
				«ENDFOR»
				«FOR vw : model.initViews»
					map.put(«vw.name.pascalize».CONTENT_URI, «vw.name.pascalize».VIEW_URIS);
				«ENDFOR»
				
				REFERENCING_VIEWS = Collections.unmodifiableMap(map);
				
			}
			
			private «model.databaseName.pascalize»Contract(){}
			
			/**
			 * <p>Delete all rows from all tables</p>
			 */						
			public static void deleteAll() {
				«FOR tbl : snapshot.tables»
					«tbl.name.pascalize».delete();
				«ENDFOR»
				«FOR tbl : model.initTables»
					«tbl.name.pascalize».delete();
				«ENDFOR»
			}
		}
	'''

	def createActionUriBuilder(ActionStatement action) '''
		/**
		 * Create a new URI for «action.uri.asString»
		 «IF !action.params.empty»
		 	* <b>Query Params:</b>
		 	«FOR param : action.params»
		 		* «param.column.name»
		 	«ENDFOR»
		 «ENDIF»
		 */
		public static class «action.name.pascalize»UriBuilder extends MickeyUriBuilder {
			public «action.name.pascalize»UriBuilder(«action.uri.toMethodArgsSig») {
				super(BASE_CONTENT_URI.buildUpon());
				getUriBuilder()
				«FOR seg : action.uri.segments»
					«IF seg instanceof ContentUriParamSegment»
						«IF (seg as ContentUriParamSegment).param.inferredColumnType != ColumnType::TEXT»
							.appendPath(String.valueOf(«seg.param.name.camelize»))
						«ELSE»
							.appendPath(«seg.param.name.camelize»)
						«ENDIF»
					«ELSE»
						.appendPath("«seg.name»")
					«ENDIF»
				«ENDFOR»;
			}
			
			«FOR queryParam : action.params»
				public «action.name.pascalize»UriBuilder set«queryParam.column.name.pascalize»Param(«queryParam.column.
			inferredColumnType.toJavaTypeName» value) {
					«IF queryParam.column.inferredColumnType == ColumnType::TEXT»
						getUriBuilder().appendQueryParameter(«action.type.name.pascalize».«queryParam.column.name.underscore.toUpperCase», value);
					«ELSEIF queryParam.column.inferredColumnType == ColumnType::BOOLEAN»
						getUriBuilder().appendQueryParameter(«action.type.name.pascalize».«queryParam.column.name.underscore.toUpperCase», value ? "1" : "0");
					«ELSE»
						getUriBuilder().appendQueryParameter(«action.type.name.pascalize».«queryParam.column.name.underscore.toUpperCase», String.valueOf(value));
					«ENDIF»
					return this;
				}
			«ENDFOR»
		}
		
		/**
		 * Create a new URI for «action.uri.asString»
		 «IF !action.params.empty»
		 	* <b>Query Params:</b>
		 	«FOR param : action.params»
		 		* «param.column.name»
		 	«ENDFOR»
		 «ENDIF»
		 */
		public static «action.name.pascalize»UriBuilder new«action.name.pascalize»UriBuilder(«action.uri.toMethodArgsSig») {
			return new «action.name.pascalize»UriBuilder(«action.uri.toMethodArgs»);
		}
	'''

	def asString(ContentUri uri) {
		var builder = new StringBuilder
		for (seg : uri.segments) {
			builder.append("/")
			if (seg instanceof ContentUriParamSegment) {
				var param = seg as ContentUriParamSegment
				builder.append("{").append(param.param.name).append("}")
			} else {
				builder.append(seg.name)
			}
		}

		return builder.toString
	}

	/*
	 * Find all actions associated to the given definition,
	 * actions are associated to the definition via the first
	 * part of an action uri, for instance /recipes/a/b/c is
	 * associated to recipes
	 */
	def Iterable<ActionStatement> findActionsForDefinition(MickeyDatabaseModel model, String defName) {
		return model.actions.filter([action|action.type.name.equals(defName)])
	}

	def toMethodArgsSig(ContentUri uri) {
		uri.segments.filter(typeof(ContentUriParamSegment)).join(", ",
			[seg|
				(
				if (seg.param.inferredColumnType != ColumnType::TEXT) {
					return "long " + seg.param.name.camelize
				} else {
					return "String " + seg.param.name.camelize
				})])
	}

	def toMethodArgs(ContentUri uri) {
		uri.segments.filter(typeof(ContentUriParamSegment)).join(", ",
			[seg|
				(
				if (seg.param.inferredColumnType != ColumnType::TEXT) {
					return seg.param.name.camelize
				} else {
					return seg.param.name.camelize
				})])
	}

	def hasMethodArgs(ContentUri uri) {
		uri.segments.filter(typeof(ContentUriParamSegment)).size > 0
	}

	def generateContractItem(MickeyDatabaseModel model, SqliteDatabaseSnapshot snapshot, TableDefinition stmt,
		ContentUris content) '''
		/**
		 * <p>Column definitions and helper methods to work with the «stmt.name.pascalize».</p>
		 */
		public static class «stmt.name.pascalize» implements «stmt.name.pascalize»Columns«IF stmt.hasAndroidPrimaryKey», BaseColumns«ENDIF» {
		    public static final Uri CONTENT_URI = 
					BASE_CONTENT_URI.buildUpon().appendPath("«stmt.name»").build();
		
		    
			/**
			 * <p>The content type for a cursor that contains many «stmt.name.pascalize» rows.</p>
			 */
			   public static final String CONTENT_TYPE =
			           "vnd.android.cursor.dir/vnd.«model.databaseName.toLowerCase».«stmt.name»";
		
			/**
			 * <p>The content type for a cursor that contains a single «stmt.name.pascalize» row.</p>
			 */
			public static final String ITEM_CONTENT_TYPE =
				"vnd.android.cursor.item/vnd.«model.databaseName.toLowerCase».«stmt.name»";
		
			/**
			 * <p>Builds a Uri with appended id for a row in «stmt.name.pascalize», 
			 * eg:- «stmt.name.toLowerCase»/123.</p>
			 */
			   public static Uri buildUriWithId(long id) {
			       return CONTENT_URI.buildUpon().appendPath(String.valueOf(id)).build();
			   }
			   «var actions = model.findActionsForDefinition(stmt.name)»
			«IF actions != null»
				«FOR action : actions»
					«action.createActionUriBuilder»
					
				«ENDFOR»
			«ENDIF»
			public static int delete() {
				return Mickey.getContentResolver().delete(«stmt.name.pascalize».CONTENT_URI, null, null);
			}
			
			public static int delete(String where, String[] selectionArgs) {
				return Mickey.getContentResolver().delete(«stmt.name.pascalize».CONTENT_URI, where, selectionArgs);
			}
			
			/**
			 * <p>Create a new Builder for «stmt.name.pascalize»</p>
			 */
			public static Builder newBuilder() {
				return new Builder();
			}
			
			/**
			 * <p>Create a new Builder for «stmt.name.pascalize»</p>
			 */
			public static Builder newBuilder(Uri contentUri) {
				return new Builder(contentUri);
			}
			
			/**
			 * <p>Build and execute insert or update statements for «stmt.name.pascalize».</p>
			 *
			 * <p>Use {@link «stmt.name.pascalize»#newBuilder()} to create new builder</p>
			 */
			public static class Builder extends AbstractValuesBuilder {
				private Builder(Uri contentUri) {
					super(Mickey.getApplicationContext(), contentUri);
				}
				private Builder() {
					super(Mickey.getApplicationContext(), «stmt.name.pascalize».CONTENT_URI);
				}
				
				«generateBuilderSetters(stmt)»
			}
			
			static final Set<Uri> VIEW_URIS;
			
			static {
				Set<Uri> viewUris =  new HashSet<>();
				«var views = snapshot.getAllViewsReferencingTable(stmt).sortBy[x|x.name]»
				«var initViews = model.getAllViewsInConfigInitReferencingTable(stmt).sortBy[x|x.name]»

				«FOR ref : views»
					viewUris.add(«ref.name.pascalize».CONTENT_URI);
				«ENDFOR»
				«FOR ref : initViews»
					viewUris.add(«ref.name.pascalize».CONTENT_URI);
				«ENDFOR»

				VIEW_URIS = Collections.unmodifiableSet(viewUris);
			}
		}
	'''

	def dispatch generateBuilderSetters(CreateTableStatement stmt) '''
		«FOR item : stmt.columnDefs.filter([!name.equals("_id")])»
			«var col = item as ColumnDef»
			public Builder set«col.name.pascalize»(«col.type.toJavaTypeName» value) {
				mValues.put(«stmt.name.pascalize».«col.name.underscore.toUpperCase», value);
				return this;
			}
		«ENDFOR»
	'''

	def dispatch generateBuilderSetters(CreateViewStatement stmt) '''
		«var cols = stmt.viewResultColumns»
		«FOR item : cols.filter([!name.equals("_id")])»
			«var col = item as ResultColumn»
			«var type = col.inferredColumnType»
			public Builder set«col.name.pascalize»(«type.toJavaTypeName» value) {
				mValues.put(«stmt.name.pascalize».«col.name.underscore.toUpperCase», value);
				return this;
			}
		«ENDFOR»
	'''

	def dispatch getName(CreateTableStatement stmt) {
		stmt.name
	}

	def dispatch getName(CreateViewStatement stmt) {
		stmt.name
	}

	def dispatch hasAndroidPrimaryKey(CreateTableStatement stmt) {
		ModelUtil::hasAndroidPrimaryKey(stmt)
	}

	def dispatch hasAndroidPrimaryKey(CreateViewStatement stmt) {
		ModelUtil::hasAndroidPrimaryKey(stmt)
	}

	def createMethodArgsFromColumns(CreateTableStatement tbl) {
		'''«FOR item : tbl.columnDefs.filter([!name.equals("_id")]) SEPARATOR ", "»«var col = item as ColumnDef»«col.
			type.toJavaTypeName()» «col.name.camelize»«ENDFOR»'''
	}

	def generateInterfaceMemberForResultColumn(ColumnSource expr) {
		'''
			«IF expr.name != null && !expr.name.equals("") && !expr.name.equals("_id")»
				String «expr.name.underscore.toUpperCase» = "«expr.name»";
			«ENDIF»
		'''
	}

}