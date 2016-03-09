module T3.Match
  ( module T3.Match.Types
  , runMatch
  , UserInit
  , Callback
  , StartCallback
  ) where

import Prelude
import T3.Match.Types
import T3.Game
import T3.Comm.Types
import T3.Comm.Class
import T3.Comm.Game

import Control.Monad.State.Strict

import Data.Text (Text)

type Callback = Board -> IO ()
type StartCallback =
  Text -> -- GameId
  Text -> -- GameToken
  Board ->
  IO ()

data MatchData = MatchData
  { matchReq :: XO -> IO (Loc, Callback)
  , matchRespX :: Callback
  , matchRespO :: Callback
  , matchLog :: Win XO -> Lose XO -> Board -> IO ()
  , matchBoard :: Board
  }

newtype Match a = Match { unMatch :: StateT MatchData IO a }
  deriving (Functor, Applicative, Monad, MonadIO, MonadState MatchData)

type UserInit = (UserId, Callback, IO (Loc, Callback))

runMatch
  :: UserInit
  -> UserInit
  -> (Win UserId -> Lose UserId -> Board -> IO ())
  -> IO ()
runMatch (xUI, xCB, xReq) (oUI, oCB, oReq) logger = let
  req X = xReq
  req O = oReq
  cb X = xCB
  cb O = oCB
  ui X = xUI
  ui O = oUI
  b = emptyBoard
  matchDat = MatchData req (cb X) (cb O) (\w l -> logger (fmap ui w) (fmap ui l)) b
  in evalStateT (unMatch $ run b) matchDat

instance Comm Match where
  sendGameState xo = do
    s <- get
    liftIO $ (respXO xo s) (matchBoard s)
  recvMove xo = do
    req <- gets (flip matchReq xo)
    (loc, resp) <- liftIO req
    updateResp resp
    return loc
    where
      updateResp resp = do
        match <- get
        put $ case xo of
          X -> match { matchRespX = resp }
          O -> match { matchRespO = resp }
  sendFinal xo final = do
    s <- get
    liftIO $ (respXO xo s) (matchBoard s)
  tally w l = do
    s <- get
    liftIO $ (matchLog s) w l (matchBoard s)
  updateBoard b = do
    match <- get
    put $ match { matchBoard = b }

respXO :: XO -> MatchData -> Callback
respXO X = matchRespX
respXO O = matchRespO

instance Game Match  where
  move = move'
  forfeit = forfeit'
  end = end'
  tie = tie'
  step = step'
