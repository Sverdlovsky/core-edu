from fastapi.responses import RedirectResponse, JSONResponse
from starlette.middleware.sessions import SessionMiddleware
from authlib.integrations.starlette_client import OAuth
from fastapi import FastAPI, Request, HTTPException
from starlette.responses import Response
from starlette.config import Config
import jwt, json, datetime, os


PATH = 'keys/oauth.json'
config_data = json.load(open(PATH, encoding='utf-8'))
config = Config(environ=config_data)
SECRET_KEY = config_data['SECRET_KEY']
JWT_SECRET = config_data.get('JWT_SECRET', SECRET_KEY)
JWT_ALGORITHM = 'HS256'
JWT_EXP_DELTA_SECONDS = 3600

app = FastAPI()
app.add_middleware(SessionMiddleware, secret_key=SECRET_KEY)

oauth = OAuth(config)
oauth.register(
    name='yandex',
    client_id=config('YANDEX_CLIENT_ID'),
    client_secret=config('YANDEX_CLIENT_SECRET'),
    access_token_url='https://oauth.yandex.ru/token',
    authorize_url='https://oauth.yandex.ru/authorize',
    api_base_url='https://login.yandex.ru/info',
    client_kwargs={'scope': 'login:email login:info'},
)
oauth.register(
    name='google',
    client_id=config('GOOGLE_CLIENT_ID'),
    client_secret=config('GOOGLE_CLIENT_SECRET'),
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={'scope': 'openid email profile'},
)
# oauth.register(
#     name='github',
#     client_id=config('GITHUB_CLIENT_ID'),
#     client_secret=config('GITHUB_CLIENT_SECRET'),
#     access_token_url='https://github.com/login/oauth/access_token',
#     access_token_params=None,
#     authorize_url='https://github.com/login/oauth/authorize',
#     authorize_params=None,
#     api_base_url='https://api.github.com/',
#     client_kwargs={'scope': 'read:user user:email'},
# )

@app.get("/with/{provider}")
async def login(request: Request, provider: str, next: str = "https://example.com/"):
    client = oauth.create_client(provider)
    if not client:
        raise HTTPException(status_code=404, detail="Unknown provider")

    request.session["next"] = next
    redirect_uri = request.url_for("auth", provider=provider)
    return await client.authorize_redirect(request, redirect_uri)

@app.get('/with/{provider}/callback')
async def auth(request: Request, provider: str):
    client = oauth.create_client(provider)
    if not client:
        raise HTTPException(status_code=404, detail='Unknown provider')

    token = await client.authorize_access_token(request)

    match provider:
        case 'yandex':
            resp = await client.get('', token=token)
            user_info = resp.json()
        case 'google':
            user_info = token.get('userinfo')
        case 'github':
            resp = await client.get('user', token=token)
            user_info = resp.json()
        case _:
            raise HTTPException(status_code=400, detail='Unsupported provider')

    payload = {
        'sub': user_info.get('email') or user_info.get('login'),
        'name': user_info.get('name', ''),
        'exp': datetime.datetime.utcnow() + datetime.timedelta(seconds=JWT_EXP_DELTA_SECONDS)
    }
    jwt_token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

    next_url = request.session.pop("next", "https://example.com/")

    response = RedirectResponse(url=next_url)
    response.set_cookie(
        key='access_token',
        value=jwt_token,
        httponly=True,
        domain='.example.com',
        secure=True,
        samesite='lax'
    )
    return response
