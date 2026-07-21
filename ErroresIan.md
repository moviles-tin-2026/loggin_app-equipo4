
# Falta de Restricción de Acceso en Módulo de Usuarios (UsersPage) #

## Se ha identificado una falla crítica en la lógica de control de acceso dentro del módulo de gestión de usuarios (users). A pesar de que la interfaz permite alternar el estado de una cuenta entre Activo e Inactivo, la función encargada de denegar el acceso al portal no está operando ni validándose correctamente durante el flujo de autenticación (LoginPage). ##

### Comportamiento Actual: Cuando una cuenta es marcada como Inactiva desde el panel de administración, el sistema actualiza el registro visual, pero el usuario afectado conserva la capacidad de iniciar sesión y navegar por el sistema sin ninguna restricción. ###

### Se espera que al intentar iniciar sesión con credenciales asociadas a un usuario en estado Inactivo, la aplicación debe invalidar inmediatamente la sesión (signOut), denegar el paso hacia el sistema y presentar un aviso claro notificando la suspensión de la cuenta. ###

#### Pendiente de corrección - Requerido el 21/07/2026. ####
