{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeOperators #-}

module Api.Server
    ( server
    , Config (..)
    , HandlerT
    ) where

import           Control.Monad (unless)
import           Control.Monad.Except (MonadError, throwError)
import           Control.Monad.IO.Class (liftIO)
import           Control.Monad.Logger
import           Control.Monad.Reader
import           Data.Monoid ((<>))
import           Data.Text (Text, toLower)
import           Data.UUID (toText)
import           Data.UUID.V4 (nextRandom)
import           Jose.Jwk
import           Prelude hiding (id)
import           Servant ((:<|>) ((:<|>)), ServerT, ServantErr, err401, err403, err404, errBody, Handler)

import           Api.Auth (AccessScope(..), mkAccessToken, scopeSubjectId)
import           Api.Types hiding (AccessToken)
import           DB (DB)
import qualified DB

data Config db = Config
    { database :: db
    , tokenKey :: Jwk
    , sampleStories :: [Story]
    }

type HandlerT db = LoggingT (ReaderT (Config db) Handler)

type ApiServer a db = ServerT a (HandlerT db)

runDB :: MonadReader (Config b) m => (b -> m b1) -> m b1
runDB f = ask >>= f . database

server :: DB db => ApiServer Api db
server = storyServer :<|> dictServer :<|> schoolsServer :<|> schoolServer :<|> trailsServer :<|> loginServer

newUUID :: HandlerT db Text
newUUID = liftIO (toText <$> nextRandom)

loginServer :: DB db => ApiServer LoginApi db
loginServer authReq = do
    logInfoN $ "Login request from: " <> uName
    user <- runDB $ DB.getAccountByUsername uName
    case user of
        Nothing -> logInfoN ("User not found: " <> uName) >> throwError err401
        Just a -> do
            unless (validatePassword (password (a :: Account)) (password (authReq :: LoginRequest)))
                (throwError err401)
            (accessToken, nm) <- createToken a

            return $ Login (id (a :: Account)) uName nm (role (a :: Account)) accessToken
  where
    uName = toLower $ username (authReq :: LoginRequest)

    validatePassword passwd encodedPasswd = passwd == encodedPasswd

    createToken acct = do
        let subId = id (acct :: Account)
        (scope, nm) <- case userType (role (acct :: Account)) of
            "Student" -> do
                 stdnt <- runDB $ DB.getStudentBySubjectId subId
                 return (StudentScope subId (schoolId (stdnt :: Student)), name (stdnt :: Student))
            "Teacher" -> do
                 teachr <- runDB $ DB.getTeacherBySubjectId subId
                 return (TeacherScope subId (schoolId (teachr :: Teacher)), name (teachr :: Teacher))
        jwk <- fmap tokenKey ask
        token_ <- mkAccessToken jwk scope
        return (token_, nm)


storyServer :: DB db => ApiServer StoriesApi db
storyServer token_ =
    getStories :<|> getStory :<|> createStory
  where
    notFound = err404 { errBody = "Story with this ID was not found" }

    getStories =
        case token_ of
            Nothing -> fmap sampleStories ask
            _ -> runDB DB.getStories

    getStory storyId_ = do
        story <- runDB (DB.getStory storyId_)
        case story of
            Nothing -> throwError notFound
            Just s -> return s

    createStory story = do
        uuid <- liftIO (toText <$> nextRandom)
        let storyWithId = story { id = uuid } :: Story
        _ <- runDB (DB.createStory storyWithId)
        return storyWithId


trailsServer :: DB db => ApiServer TrailsApi db
trailsServer Nothing = throwAll err401
trailsServer (Just (TeacherScope _ sid)) =
    getTrailsForSchool sid :<|> createTrail
trailsServer (Just (StudentScope _ sid)) =
    getTrailsForSchool sid :<|> throwAll err403
trailsServer _ = throwAll err403

getTrailsForSchool :: DB db => SchoolId -> HandlerT db [StoryTrail]
getTrailsForSchool = runDB . DB.getTrails

createTrail :: DB db => StoryTrail -> HandlerT db StoryTrail
createTrail trail = do
    uuid <- liftIO (toText <$> nextRandom)
    let trailWithId = trail { id = uuid } :: StoryTrail
    _ <- runDB (DB.createTrail trailWithId)
    return trailWithId


schoolsServer :: DB db => ApiServer SchoolsApi db
schoolsServer Nothing = throwAll err401
schoolsServer (Just scp@(AdminScope _)) = runDB DB.getSchools :<|> specificSchoolServer scp
schoolsServer _ = throwAll err403


schoolServer :: DB db => ApiServer SchoolApi db
schoolServer Nothing = throwAll err401
schoolServer (Just scp@(TeacherScope _ sid)) = specificSchoolServer scp sid
schoolServer (Just scp@(StudentScope _ _)) = throwAll err403 :<|> throwAll err403 :<|> answersServer scp
schoolServer _ = throwAll err403


specificSchoolServer :: DB db => AccessScope -> SchoolId -> ApiServer (ClassesApi :<|> StudentsApi :<|> AnswersApi) db
specificSchoolServer scp sid = classesServer (scopeSubjectId scp) sid :<|> studentsServer sid :<|> answersServer scp


classesServer :: DB db => SubjectId -> SchoolId -> ApiServer ClassesApi db
classesServer subId sid = runDB (DB.getClasses sid) :<|> getClass :<|> createClass
  where
    getClass cid = do
        c <- runDB (DB.getClass cid)
        maybe (throwError err404) return c

    createClass (nm, desc) = do
        uuid <- newUUID
        let c = Class uuid nm (Just desc) sid subId []
        _ <- runDB (DB.createClass c)
        return c


studentsServer :: DB db => SchoolId -> ApiServer StudentsApi db
studentsServer schoolId_ = runDB (DB.getStudents schoolId_) :<|> getStudent :<|> mapM createStudent
  where
    getStudent studId = do
        s <- runDB $ DB.getStudent schoolId_ studId
        maybe (throwError err404) return s

    generateUsername nm = return nm

    generatePassword = return "password"

    createStudent nm = do
        username <- generateUsername nm
        password <- generatePassword

        let creds = (username, password)
        stdnt <- runDB $ DB.createStudent (nm, 5, schoolId_) creds
        return (stdnt, creds)


answersServer :: DB db => AccessScope -> ApiServer AnswersApi db
answersServer (TeacherScope _ schoolId_) = runDB (DB.getAnswers schoolId_) :<|> throwAll err403
answersServer (StudentScope subId schoolId_ ) = runDB (DB.getAnswers schoolId_) :<|> createAnswer
  where
    createAnswer a = do
        uuid <- newUUID
        let a_ = a { id = uuid, studentId = subId } :: Answer
        _ <- runDB $ DB.createAnswer (a_, schoolId_)
        return a_
answersServer _ = throwAll err403

dictServer :: DB db => ApiServer DictApi db
dictServer =
    runDB DB.getDictionary :<|> runDB . DB.lookupWord

-- ThrowAll idea taken from servant-auth
class ThrowAll a where
    throwAll :: ServantErr -> a

instance (ThrowAll a, ThrowAll b) => ThrowAll (a :<|> b) where
    throwAll e = throwAll e :<|> throwAll e

instance {-# OVERLAPS #-} ThrowAll b => ThrowAll (a -> b) where
    throwAll e = const $ throwAll e

instance {-# OVERLAPPABLE #-} (MonadError ServantErr m) => ThrowAll (m a) where
    throwAll = throwError
