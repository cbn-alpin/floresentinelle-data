BEGIN ;

ALTER TABLE utilisateurs.t_roles ADD CONSTRAINT unique_email UNIQUE (email) ;
ALTER TABLE utilisateurs.t_roles ADD CONSTRAINT unique_identifiant UNIQUE (identifiant) ;

COMMIT ;
